// Map store search using multiple public Overpass mirrors. Never return invented stores.
const cache = new Map();
function haversine(a,b,c,d){const R=6371,r=Math.PI/180,da=(c-a)*r,db=(d-b)*r;const h=Math.sin(da/2)**2+Math.cos(a*r)*Math.cos(c*r)*Math.sin(db/2)**2;return 2*R*Math.asin(Math.min(1,Math.sqrt(h)));}
const mirrors=['https://overpass.kumi.systems/api/interpreter','https://overpass.private.coffee/api/interpreter','https://overpass-api.de/api/interpreter'];
async function lookup(endpoint,query){
 const controller=new AbortController();const timer=setTimeout(()=>controller.abort(),9500);
 try{const response=await fetch(endpoint,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded;charset=UTF-8','User-Agent':'FamilieKurv/0.9.6 personal shopping prototype'},body:'data='+encodeURIComponent(query),signal:controller.signal});if(!response.ok)throw Error('Map server HTTP '+response.status);const data=await response.json();if(!Array.isArray(data.elements))throw Error('Invalid map response');return data;}
 finally{clearTimeout(timer);}
}
export default async function handler(req,res){
 res.setHeader('Cache-Control','public, s-maxage=1200, stale-while-revalidate=3600');
 const lat=Number(req.query.lat),lon=Number(req.query.lon);
 if(!Number.isFinite(lat)||!Number.isFinite(lon)||lat<54||lat>58||lon<7||lon>16)return res.status(400).json({error:'Select a location within Denmark.'});
 const key=lat.toFixed(2)+':'+lon.toFixed(2),hit=cache.get(key);
 if(hit&&Date.now()-hit.at<1800000)return res.status(200).json(hit.data);
 // 12 km first search covers default 5 km and provides fallback stores.
 const query=`[out:json][timeout:12];nwr["shop"="supermarket"](around:12000,${lat},${lon});out center tags;`;
 try{
  const data=await Promise.any(mirrors.map(m=>lookup(m,query)));
  const stores=[],seen=new Set();
  for(const el of data.elements){const t=el.tags||{},a=el.lat??el.center?.lat,b=el.lon??el.center?.lon;if(!Number.isFinite(a)||!Number.isFinite(b))continue;const id=el.type+':'+el.id;if(seen.has(id))continue;seen.add(id);const name=String(t.name||t.brand||t.operator||'Supermarket');stores.push({name,chain:String(t.brand||t.name||t.operator||''),address:[t['addr:street'],t['addr:housenumber']].filter(Boolean).join(' '),lat:a,lon:b,distance:Math.round(haversine(lat,lon,a,b)*10)/10});}
  stores.sort((a,b)=>a.distance-b.distance);
  const result={stores:stores.slice(0,180),source:'OpenStreetMap via Overpass',distance_type:'straight_line_km'};
  cache.set(key,{at:Date.now(),data:result});return res.status(200).json(result);
 }catch(e){if(hit)return res.status(200).json({...hit.data,cached:true});return res.status(503).json({error:'Public supermarket map lookup is temporarily unavailable. Please try again later.'});}
}
