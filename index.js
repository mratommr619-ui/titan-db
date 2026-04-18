export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "POST", "Access-Control-Allow-Headers": "Content-Type" } });
    }

    try {
      const { deviceId } = await request.json();
      
      // GitHub API ခေါ်မယ်
      const res = await fetch("https://api.github.com/repos/mratommr619-ui/titan-db/contents/users.json", {
        headers: { 
          "Authorization": `token ${env.GITHUB_TOKEN}`, 
          "User-Agent": "Cloudflare-Worker" 
        }
      });
      
      const data = await res.json();
      const content = JSON.parse(atob(data.content));
      
      const isAuthorized = content.users.hasOwnProperty(deviceId);
      const expiry = isAuthorized ? content.users[deviceId] : "No Access";

      return new Response(JSON.stringify({ status: isAuthorized, expiry: expiry }), {
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    } catch (e) {
      return new Response(JSON.stringify({ error: e.message }), { status: 500 });
    }
  }
}