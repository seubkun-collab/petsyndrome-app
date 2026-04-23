export default {
  async fetch(request, env) {

    const url = new URL(request.url);

    // 저장 API
    if (url.pathname === "/api/save") {
      const body = await request.json();
      await env.PET_KV.put("data", JSON.stringify(body));
      return new Response("saved");
    }

    // 불러오기 API
    if (url.pathname === "/api/load") {
      const data = await env.PET_KV.get("data");
      return new Response(data || "{}");
    }

    return new Response("API OK");
  },
};
