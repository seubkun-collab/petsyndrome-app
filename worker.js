/**
 * 펫신드룸 단가 계산 시스템 - Cloudflare Workers 백엔드
 * KV 저장소를 사용해 원물/작업비/포장/레시피 데이터를 서버에 영속 저장
 */

// ── CORS 헤더 ──
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}

function err(msg, status = 400) {
  return json({ error: msg }, status);
}

// ── 기본 초기 데이터 ──
const DEFAULT_INGREDIENTS = [
  { id: 'ing-001', name: '닭가슴살', type: 'raw', unitPrice: 3500, moisture: 0.75, crudeProtein: 23.0, crudeFat: 1.2, crudeAsh: 1.1, crudeFiber: 0.0, calcium: 0.01, phosphorus: 0.2, isActive: true, bulkWeightKg: 10.0, history: [], updatedAt: new Date().toISOString() },
  { id: 'ing-002', name: '연어', type: 'raw', unitPrice: 8000, moisture: 0.70, crudeProtein: 20.0, crudeFat: 13.0, crudeAsh: 1.3, crudeFiber: 0.0, calcium: 0.02, phosphorus: 0.25, isActive: true, bulkWeightKg: 10.0, history: [], updatedAt: new Date().toISOString() },
  { id: 'ing-003', name: '북어', type: 'raw', unitPrice: 12000, moisture: 0.15, crudeProtein: 80.0, crudeFat: 1.0, crudeAsh: 5.0, crudeFiber: 0.0, calcium: 0.15, phosphorus: 0.8, isActive: true, bulkWeightKg: 10.0, history: [], updatedAt: new Date().toISOString() },
  { id: 'ing-004', name: '명태', type: 'raw', unitPrice: 4500, moisture: 0.80, crudeProtein: 17.0, crudeFat: 0.5, crudeAsh: 1.2, crudeFiber: 0.0, calcium: 0.05, phosphorus: 0.2, isActive: true, bulkWeightKg: 10.0, history: [], updatedAt: new Date().toISOString() },
  { id: 'ing-005', name: '열빙어', type: 'raw', unitPrice: 3000, moisture: 0.78, crudeProtein: 15.0, crudeFat: 3.0, crudeAsh: 2.0, crudeFiber: 0.0, calcium: 0.3, phosphorus: 0.25, isActive: true, bulkWeightKg: 10.0, history: [], updatedAt: new Date().toISOString() },
  { id: 'ing-006', name: '산양유', type: 'raw', unitPrice: 15000, moisture: 0.87, crudeProtein: 3.5, crudeFat: 4.0, crudeAsh: 0.8, crudeFiber: 0.0, calcium: 0.13, phosphorus: 0.1, isActive: true, bulkWeightKg: 10.0, history: [], updatedAt: new Date().toISOString() },
  { id: 'ing-007', name: '치즈', type: 'raw', unitPrice: 18000, moisture: 0.40, crudeProtein: 25.0, crudeFat: 30.0, crudeAsh: 4.0, crudeFiber: 0.0, calcium: 0.7, phosphorus: 0.5, isActive: true, bulkWeightKg: 10.0, history: [], updatedAt: new Date().toISOString() },
  { id: 'ing-008', name: '고구마', type: 'raw', unitPrice: 2000, moisture: 0.68, crudeProtein: 1.6, crudeFat: 0.1, crudeAsh: 0.9, crudeFiber: 3.0, calcium: 0.03, phosphorus: 0.05, isActive: true, bulkWeightKg: 10.0, history: [], updatedAt: new Date().toISOString() },
  { id: 'ing-009', name: '단호박', type: 'raw', unitPrice: 1800, moisture: 0.91, crudeProtein: 1.0, crudeFat: 0.1, crudeAsh: 0.6, crudeFiber: 2.7, calcium: 0.02, phosphorus: 0.04, isActive: true, bulkWeightKg: 10.0, history: [], updatedAt: new Date().toISOString() },
  { id: 'ing-010', name: '브로콜리', type: 'raw', unitPrice: 2500, moisture: 0.90, crudeProtein: 2.8, crudeFat: 0.4, crudeAsh: 0.9, crudeFiber: 2.6, calcium: 0.05, phosphorus: 0.07, isActive: true, bulkWeightKg: 10.0, history: [], updatedAt: new Date().toISOString() },
  { id: 'ing-011', name: '소고기', type: 'raw', unitPrice: 12000, moisture: 0.70, crudeProtein: 21.0, crudeFat: 8.0, crudeAsh: 1.0, crudeFiber: 0.0, calcium: 0.01, phosphorus: 0.2, isActive: true, bulkWeightKg: 10.0, history: [], updatedAt: new Date().toISOString() },
  { id: 'ing-012', name: '오리고기', type: 'raw', unitPrice: 5500, moisture: 0.72, crudeProtein: 19.0, crudeFat: 6.0, crudeAsh: 1.1, crudeFiber: 0.0, calcium: 0.01, phosphorus: 0.18, isActive: true, bulkWeightKg: 10.0, history: [], updatedAt: new Date().toISOString() },
];

const DEFAULT_WORK_COST = {
  id: 'default',
  dryingCost: 2000,
  mixingCost: 1000,
  cuttingCost: 1000,
  cuttingLossRate: 0.05,
  marginRate: 0.30,
  changedBy: '관리자',
  history: [],
  updatedAt: new Date().toISOString(),
};

const DEFAULT_PACKAGINGS = [
  { id: 'pkg-001', name: '비닐포장', category: 'vinyl', containerPrice: 50, packagingCost: 200, isActive: true, sortOrder: 0, history: [], updatedAt: new Date().toISOString() },
  { id: 'pkg-002', name: '샘플포장', category: 'sample', containerPrice: 30, packagingCost: 150, isActive: true, sortOrder: 1, history: [], updatedAt: new Date().toISOString() },
  { id: 'pkg-003', name: '300cc 통', category: 'container', containerPrice: 800, packagingCost: 500, volumeCC: 300, isActive: true, sortOrder: 2, history: [], updatedAt: new Date().toISOString() },
  { id: 'pkg-004', name: '400cc 통', category: 'container', containerPrice: 900, packagingCost: 550, volumeCC: 400, isActive: true, sortOrder: 3, history: [], updatedAt: new Date().toISOString() },
  { id: 'pkg-005', name: '500cc 통', category: 'container', containerPrice: 1000, packagingCost: 600, volumeCC: 500, isActive: true, sortOrder: 4, history: [], updatedAt: new Date().toISOString() },
  { id: 'pkg-006', name: '600cc 통', category: 'container', containerPrice: 1100, packagingCost: 650, volumeCC: 600, isActive: true, sortOrder: 5, history: [], updatedAt: new Date().toISOString() },
  { id: 'pkg-007', name: '700cc 통', category: 'container', containerPrice: 1200, packagingCost: 700, volumeCC: 700, isActive: true, sortOrder: 6, history: [], updatedAt: new Date().toISOString() },
  { id: 'pkg-008', name: '1000cc 통', category: 'container', containerPrice: 1500, packagingCost: 800, volumeCC: 1000, isActive: true, sortOrder: 7, history: [], updatedAt: new Date().toISOString() },
  { id: 'pkg-009', name: '1200cc 통', category: 'container', containerPrice: 1700, packagingCost: 900, volumeCC: 1200, isActive: true, sortOrder: 8, history: [], updatedAt: new Date().toISOString() },
  { id: 'pkg-010', name: '1500cc 통', category: 'container', containerPrice: 2000, packagingCost: 1000, volumeCC: 1500, isActive: true, sortOrder: 9, history: [], updatedAt: new Date().toISOString() },
];

// ── KV 헬퍼 ──
async function kvGet(kv, key, fallback = null) {
  const val = await kv.get(key, 'json');
  return val !== null ? val : fallback;
}

async function kvPut(kv, key, value) {
  await kv.put(key, JSON.stringify(value));
}

// ── 초기 데이터 시드 ──
async function ensureSeeded(kv) {
  const seeded = await kv.get('seeded_v1');
  if (seeded) return;

  await kvPut(kv, 'ingredients', DEFAULT_INGREDIENTS);
  await kvPut(kv, 'workcost', DEFAULT_WORK_COST);
  await kvPut(kv, 'packagings', DEFAULT_PACKAGINGS);
  await kvPut(kv, 'recipes', []);
  await kv.put('seeded_v1', 'true');
}

// ── 라우터 ──
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // OPTIONS (CORS preflight)
    if (method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }

    const kv = env.PET_KV;

    // 초기 데이터 보장
    await ensureSeeded(kv);

    // ── 원물 (Ingredients) ──
    if (path === '/api/ingredients' && method === 'GET') {
      const list = await kvGet(kv, 'ingredients', []);
      return json(list);
    }

    if (path === '/api/ingredients' && method === 'POST') {
      const body = await request.json();
      const list = await kvGet(kv, 'ingredients', []);
      const newItem = { ...body, updatedAt: new Date().toISOString(), history: body.history || [] };
      list.push(newItem);
      await kvPut(kv, 'ingredients', list);
      return json(newItem, 201);
    }

    // PUT /api/ingredients/:id
    const ingPutMatch = path.match(/^\/api\/ingredients\/([^/]+)$/);
    if (ingPutMatch && method === 'PUT') {
      const id = ingPutMatch[1];
      const body = await request.json();
      const list = await kvGet(kv, 'ingredients', []);
      const idx = list.findIndex(i => i.id === id);
      if (idx === -1) return err('원물을 찾을 수 없습니다.', 404);

      const existing = list[idx];
      const updated = { ...existing, ...body, id, updatedAt: new Date().toISOString() };

      // 단가/수분율 변경 이력 자동 기록
      if (existing.unitPrice !== body.unitPrice || existing.moisture !== body.moisture) {
        const histEntry = {
          changedAt: existing.updatedAt,
          unitPrice: existing.unitPrice,
          moisture: existing.moisture,
          note: `단가: ${existing.unitPrice}→${body.unitPrice}, 수분: ${(existing.moisture*100).toFixed(1)}%→${(body.moisture*100).toFixed(1)}%`,
        };
        updated.history = [...(existing.history || []), histEntry];
      } else {
        updated.history = existing.history || [];
      }

      list[idx] = updated;
      await kvPut(kv, 'ingredients', list);
      return json(updated);
    }

    // DELETE /api/ingredients/:id
    const ingDelMatch = path.match(/^\/api\/ingredients\/([^/]+)$/);
    if (ingDelMatch && method === 'DELETE') {
      const id = ingDelMatch[1];
      let list = await kvGet(kv, 'ingredients', []);
      list = list.filter(i => i.id !== id);
      await kvPut(kv, 'ingredients', list);
      return json({ ok: true });
    }

    // ── 작업비 (WorkCost) ──
    if (path === '/api/workcost' && method === 'GET') {
      const wc = await kvGet(kv, 'workcost', DEFAULT_WORK_COST);
      return json(wc);
    }

    if (path === '/api/workcost' && method === 'PUT') {
      const body = await request.json();
      const existing = await kvGet(kv, 'workcost', DEFAULT_WORK_COST);

      const changes = [];
      if (existing.dryingCost !== body.dryingCost) changes.push(`건조비: ${existing.dryingCost}→${body.dryingCost}원`);
      if (existing.mixingCost !== body.mixingCost) changes.push(`배합비: ${existing.mixingCost}→${body.mixingCost}원`);
      if (existing.cuttingCost !== body.cuttingCost) changes.push(`절단비: ${existing.cuttingCost}→${body.cuttingCost}원`);
      if (existing.cuttingLossRate !== body.cuttingLossRate) changes.push(`절단로스: ${(existing.cuttingLossRate*100).toFixed(1)}%→${(body.cuttingLossRate*100).toFixed(1)}%`);
      if (existing.marginRate !== body.marginRate) changes.push(`마진율: ${(existing.marginRate*100).toFixed(1)}%→${(body.marginRate*100).toFixed(1)}%`);

      const updated = { ...existing, ...body, updatedAt: new Date().toISOString() };
      if (changes.length > 0) {
        const histEntry = {
          changedAt: existing.updatedAt,
          dryingCost: existing.dryingCost,
          mixingCost: existing.mixingCost,
          cuttingCost: existing.cuttingCost,
          cuttingLossRate: existing.cuttingLossRate,
          marginRate: existing.marginRate,
          note: changes.join(', '),
          changedBy: body.changedBy || '관리자',
        };
        updated.history = [...(existing.history || []), histEntry];
      } else {
        updated.history = existing.history || [];
      }

      await kvPut(kv, 'workcost', updated);
      return json(updated);
    }

    // ── 포장 (Packagings) ──
    if (path === '/api/packagings' && method === 'GET') {
      const list = await kvGet(kv, 'packagings', []);
      return json(list);
    }

    if (path === '/api/packagings' && method === 'POST') {
      const body = await request.json();
      const list = await kvGet(kv, 'packagings', []);
      const newItem = { ...body, updatedAt: new Date().toISOString(), history: body.history || [] };
      list.push(newItem);
      await kvPut(kv, 'packagings', list);
      return json(newItem, 201);
    }

    const pkgPutMatch = path.match(/^\/api\/packagings\/([^/]+)$/);
    if (pkgPutMatch && method === 'PUT') {
      const id = pkgPutMatch[1];
      const body = await request.json();
      const list = await kvGet(kv, 'packagings', []);
      const idx = list.findIndex(p => p.id === id);
      if (idx === -1) return err('포장을 찾을 수 없습니다.', 404);

      const existing = list[idx];
      const updated = { ...existing, ...body, id, updatedAt: new Date().toISOString() };

      if (existing.containerPrice !== body.containerPrice || existing.packagingCost !== body.packagingCost) {
        const histEntry = {
          changedAt: existing.updatedAt,
          containerPrice: existing.containerPrice,
          packagingCost: existing.packagingCost,
          note: `통가격: ${existing.containerPrice}→${body.containerPrice}원, 포장비: ${existing.packagingCost}→${body.packagingCost}원`,
        };
        updated.history = [...(existing.history || []), histEntry];
      } else {
        updated.history = existing.history || [];
      }

      list[idx] = updated;
      await kvPut(kv, 'packagings', list);
      return json(updated);
    }

    const pkgDelMatch = path.match(/^\/api\/packagings\/([^/]+)$/);
    if (pkgDelMatch && method === 'DELETE') {
      const id = pkgDelMatch[1];
      let list = await kvGet(kv, 'packagings', []);
      list = list.filter(p => p.id !== id);
      await kvPut(kv, 'packagings', list);
      return json({ ok: true });
    }

    // ── 레시피 (Recipes) ──
    if (path === '/api/recipes' && method === 'GET') {
      const worker = url.searchParams.get('worker');
      let list = await kvGet(kv, 'recipes', []);
      if (worker) list = list.filter(r => r.workerName === worker);
      list.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
      return json(list);
    }

    if (path === '/api/recipes' && method === 'POST') {
      const body = await request.json();
      const list = await kvGet(kv, 'recipes', []);
      const newItem = { ...body, createdAt: body.createdAt || new Date().toISOString() };
      list.push(newItem);
      await kvPut(kv, 'recipes', list);
      return json(newItem, 201);
    }

    const recipeDelMatch = path.match(/^\/api\/recipes\/([^/]+)$/);
    if (recipeDelMatch && method === 'DELETE') {
      const id = recipeDelMatch[1];
      let list = await kvGet(kv, 'recipes', []);
      list = list.filter(r => r.id !== id);
      await kvPut(kv, 'recipes', list);
      return json({ ok: true });
    }

    // ── 관리자 인증 ──
    if (path === '/api/auth/admin' && method === 'POST') {
      const body = await request.json();
      if (body.id === 'petsyndrome' && body.pw === 'a29251313') {
        // 로그인 기록 저장
        const logs = await kvGet(kv, 'login_logs', []);
        logs.unshift({ type: 'admin', id: body.id, at: new Date().toISOString(), ip: request.headers.get('CF-Connecting-IP') || '' });
        if (logs.length > 500) logs.splice(500);
        await kvPut(kv, 'login_logs', logs);
        return json({ ok: true });
      }
      return err('아이디 또는 비밀번호가 올바르지 않습니다.', 401);
    }

    // ── 직원(Staff) 계정 관리 ──
    // 회원가입 신청
    if (path === '/api/staff/register' && method === 'POST') {
      const body = await request.json();
      const { name, pin, role } = body; // role: 'staff' | 'customer'
      if (!name || !pin) return err('이름과 PIN이 필요합니다.');
      const accounts = await kvGet(kv, 'accounts', []);
      if (accounts.find(a => a.name === name && a.role === (role || 'staff'))) {
        return err('이미 존재하는 계정입니다.');
      }
      const newAccount = {
        id: `acc_${Date.now()}`,
        name,
        pin,
        role: role || 'staff',
        status: 'pending', // 'pending' | 'approved' | 'rejected'
        createdAt: new Date().toISOString(),
        approvedAt: null,
        approvedBy: null,
      };
      accounts.push(newAccount);
      await kvPut(kv, 'accounts', accounts);
      return json({ ok: true, message: '가입 신청이 완료되었습니다. 관리자 승인 후 로그인 가능합니다.' }, 201);
    }

    // 로그인
    if (path === '/api/staff/login' && method === 'POST') {
      const body = await request.json();
      const { name, pin, role } = body;
      const accounts = await kvGet(kv, 'accounts', []);
      const acc = accounts.find(a => a.name === name && a.pin === pin && a.role === (role || 'staff'));
      if (!acc) return err('이름 또는 PIN이 올바르지 않습니다.', 401);
      if (acc.status === 'pending') return err('관리자 승인 대기 중입니다.', 403);
      if (acc.status === 'rejected') return err('가입이 거부되었습니다. 관리자에게 문의하세요.', 403);
      // 로그인 기록
      const logs = await kvGet(kv, 'login_logs', []);
      logs.unshift({ type: role || 'staff', name, at: new Date().toISOString(), ip: request.headers.get('CF-Connecting-IP') || '' });
      if (logs.length > 500) logs.splice(500);
      await kvPut(kv, 'login_logs', logs);
      return json({ ok: true, account: { id: acc.id, name: acc.name, role: acc.role } });
    }

    // 대기중 계정 목록 (관리자 전용)
    if (path === '/api/staff/pending' && method === 'GET') {
      const accounts = await kvGet(kv, 'accounts', []);
      return json(accounts.filter(a => a.status === 'pending'));
    }

    // 전체 계정 목록 (관리자 전용)
    if (path === '/api/staff/list' && method === 'GET') {
      const accounts = await kvGet(kv, 'accounts', []);
      return json(accounts.map(a => ({ ...a, pin: '***' }))); // PIN 마스킹
    }

    // 계정 승인/거부 (관리자 전용)
    const approveMatch = path.match(/^\/api\/staff\/([^/]+)\/(approve|reject)$/);
    if (approveMatch && method === 'POST') {
      const [, accId, action] = approveMatch;
      const body = await request.json().catch(() => ({}));
      const accounts = await kvGet(kv, 'accounts', []);
      const idx = accounts.findIndex(a => a.id === accId);
      if (idx === -1) return err('계정을 찾을 수 없습니다.', 404);
      accounts[idx].status = action === 'approve' ? 'approved' : 'rejected';
      accounts[idx].approvedAt = new Date().toISOString();
      accounts[idx].approvedBy = body.approvedBy || 'petsyndrome';
      await kvPut(kv, 'accounts', accounts);
      return json({ ok: true });
    }

    // 계정 삭제 (관리자 전용)
    const accDelMatch = path.match(/^\/api\/staff\/([^/]+)$/);
    if (accDelMatch && method === 'DELETE') {
      const accId = accDelMatch[1];
      let accounts = await kvGet(kv, 'accounts', []);
      accounts = accounts.filter(a => a.id !== accId);
      await kvPut(kv, 'accounts', accounts);
      return json({ ok: true });
    }

    // 로그인 기록 조회 (관리자 전용)
    if (path === '/api/logs' && method === 'GET') {
      const logs = await kvGet(kv, 'login_logs', []);
      return json(logs.slice(0, 100));
    }

    // ── 헬스체크 ──
    if (path === '/api/health' && method === 'GET') {
      return json({ status: 'ok', time: new Date().toISOString() });
    }

    // ── 이카운트 ERP API 프록시 ──
    // Zone 조회 (로그인 전에 회사코드로 zone 파악)
    if (path === '/api/icount/zone' && method === 'POST') {
      const body = await request.json();
      const { companyCode } = body;
      if (!companyCode) return err('companyCode 가 필요합니다.');
      try {
        // 이카운트 공식 Zone 조회 API (운영서버)
        const res = await fetch('https://oapi.ecount.com/OAPI/V2/Zone', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
          body: JSON.stringify({ COM_CODE: companyCode }),
        });
        const data = await res.json();
        // 정상: {Status:200, Data:{ZONE:"1"}} or {Data:{ZONE:1}}
        const zone = data?.Data?.ZONE ? String(data.Data.ZONE) : null;
        if (zone) return json({ ok: true, zone });
        return json({ ok: false, zone: null, message: data?.Data?.message || 'Zone 조회 실패', raw: data });
      } catch (e) {
        return err('Zone 조회 실패: ' + e.message, 500);
      }
    }

    // 세션 로그인 (회사코드 + USER_ID + API_CERT_KEY → SESSION_ID 획득)
    // Flutter 쪽에서 apiCertKey 또는 password 필드로 보낼 수 있으므로 양쪽 모두 수용
    if (path === '/api/icount/session' && method === 'POST') {
      const body = await request.json();
      const companyCode = body.companyCode;
      const userId = body.userId;
      const zoneOverride = body.zone;
      // apiCertKey가 비어있거나 마스킹값이면 KV에서 저장된 키 사용
      let apiCertKey = body.apiCertKey || body.password || '';
      if (!apiCertKey || apiCertKey === '***saved***') {
        const savedCfg = await kvGet(kv, 'icount_config', null);
        apiCertKey = savedCfg?.apiCertKey || '';
      }
      if (!companyCode || !userId || !apiCertKey) {
        return err('companyCode, userId, apiCertKey 가 필요합니다. 설정에서 API 인증키를 저장해주세요.');
      }
      try {
        // 1단계: Zone 자동 조회
        let z = zoneOverride && zoneOverride !== 'auto' ? zoneOverride : null;
        if (!z) {
          try {
            const zRes = await fetch('https://oapi.ecount.com/OAPI/V2/Zone', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
              body: JSON.stringify({ COM_CODE: companyCode }),
            });
            const zData = await zRes.json();
            z = zData?.Data?.ZONE ? String(zData.Data.ZONE) : null;
          } catch (_) {
            z = null;
          }
        }
        // 2단계: 운영서버(oapi)로 로그인
        // Zone 있으면 oapi{ZONE}.ecount.com, 없으면 oapi.ecount.com
        const loginUrl = z
          ? `https://oapi${z}.ecount.com/OAPI/V2/OAPILogin`
          : 'https://oapi.ecount.com/OAPI/V2/OAPILogin';
        const loginRes = await fetch(loginUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
          body: JSON.stringify({
            COM_CODE: companyCode,
            USER_ID: userId,
            API_CERT_KEY: apiCertKey,
            LAN_TYPE: 'ko-KR',
            ZONE: z || '',
          }),
        });
        let data;
        const responseText = await loginRes.text();
        try {
          data = JSON.parse(responseText);
        } catch (_) {
          return err(`이카운트 서버 응답 오류: ${responseText.substring(0, 200)}`, 500);
        }
        // 응답 구조: {Status:200, Data:{Code:"00", Datas:{SESSION_ID:"..."}}}
        const sessionId = data?.Data?.Datas?.SESSION_ID || data?.Data?.SESSION_ID || null;
        const code = data?.Data?.Code;
        const statusOk = String(data?.Status) === '200' && code === '00';
        const ok = statusOk && !!sessionId;
        const errorMsg = ok ? null : (data?.Data?.Message || data?.Data?.message || `Code: ${code}`);
        return json({ ok, sessionId, zone: z, error: errorMsg, raw: ok ? undefined : data });
      } catch (e) {
        return err('이카운트 서버 연결 실패: ' + e.message, 500);
      }
    }

    // 견적서 저장 (/api/icount/estimate) - SaveSaleEstimate 또는 SaveSale
    if (path === '/api/icount/estimate' && method === 'POST') {
      const body = await request.json();
      const { sessionId, zone, estimateItems } = body;
      if (!sessionId || !estimateItems) {
        return err('sessionId 와 estimateItems 가 필요합니다.');
      }
      const z = zone || '1';
      const today = new Date();
      const dateStr = `${today.getFullYear()}${String(today.getMonth()+1).padStart(2,'0')}${String(today.getDate()).padStart(2,'0')}`;

      // 이카운트 판매견적 API
      const icountBody = {
        SaleList: estimateItems.map((item, idx) => ({
          Line: String(idx),
          BulkDatas: {
            IO_DATE: item.date || dateStr,
            CUST_DES: item.customerName || '',
            CUST: item.customerCode || '',
            PROD_CD: item.productCode || '',
            PROD_DES: item.productName || '',
            QTY: String(item.qty || 1),
            PRICE: String(Math.round(item.unitPrice || 0)),
            SUPPLY_AMT: String(Math.round((item.unitPrice || 0) * (item.qty || 1))),
            REMARKS: item.note || '',
          },
        })),
      };

      // 운영서버(oapi)로 견적서/판매 API 시도
      const endpoints = [
        `https://oapi${z}.ecount.com/OAPI/V2/SaleEstimate/SaveSaleEstimate?SESSION_ID=${sessionId}`,
        `https://oapi${z}.ecount.com/OAPI/V2/Sale/SaveSale?SESSION_ID=${sessionId}`,
      ];

      for (const endpoint of endpoints) {
        try {
          const res = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(icountBody),
          });
          const data = await res.json();
          if (data?.Status === '200') {
            return json({ ok: true, endpoint, data });
          }
        } catch (_) {}
      }
      return err('이카운트 견적서 전송 실패. 품목코드 또는 창고코드를 확인하세요.', 400);
    }

    // 이카운트 설정 저장/조회 (KV 저장) - apiCertKey 기반
    if (path === '/api/icount/config' && method === 'GET') {
      const cfg = await kvGet(kv, 'icount_config', null);
      if (cfg) return json({ ...cfg, apiCertKey: cfg.apiCertKey ? '***saved***' : '', password: cfg.apiCertKey ? '***saved***' : '' });
      return json(null);
    }

    if (path === '/api/icount/config' && method === 'POST') {
      const body = await request.json();
      // apiCertKey 또는 password 필드 모두 수용
      const companyCode = body.companyCode;
      const userId = body.userId;
      const apiCertKey = body.apiCertKey || body.password;
      const zone = body.zone;
      if (!companyCode || !userId || !apiCertKey) {
        return err('companyCode, userId, apiCertKey 가 필요합니다.');
      }
      await kvPut(kv, 'icount_config', {
        companyCode, userId, apiCertKey, zone: zone || '1',
        updatedAt: new Date().toISOString(),
      });
      return json({ ok: true });
    }

    // ── 데이터 초기화 (관리자 전용) ──
    if (path === '/api/seed' && method === 'POST') {
      const auth = request.headers.get('Authorization');
      if (auth !== 'Bearer petsyndrome_admin_seed') return err('Unauthorized', 401);
      await kv.delete('seeded_v1');
      await ensureSeeded(kv);
      return json({ ok: true, message: '초기 데이터가 복원되었습니다.' });
    }

    return err('Not Found', 404);
  },
};
