module.exports = async function handler(req,res){
  if (req.method !== 'GET') return res.status(405).json({error:'GET only'});
  res.setHeader('Cache-Control','no-store');
  const url=process.env.SUPABASE_URL||'';
  const anonKey=process.env.SUPABASE_ANON_KEY||'';
  if (!/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(url) || !anonKey)
    return res.status(503).json({error:'Supabase configuration missing'});
  return res.status(200).json({url,anonKey});
};
