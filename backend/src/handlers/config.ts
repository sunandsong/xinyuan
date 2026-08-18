// GET /config —— App 启动时一次性拉走全部配置：预设心愿/步骤模板、海报文案、
// 首页大图、成就定义、地图打卡点、生效中的公告、最低版本号。不分页，用户鉴权即可访问。
import { getDb } from '../db';
import { ok, Req } from '../http';

/** 单集合查询上限（内容表都是百级数据量，一次拉全量） */
const LIMIT = 1000;
/** announcements 集合里存最低版本号的特殊文档 id，不是一条真公告 */
const MIN_VERSION_ID = 'sys_min_version';
/** 同上，存功能开关的特殊文档 id。目前两个开关，都是「送审期间关掉、过审再打开」用的：
 * - showRank：排行榜显隐。关掉审核员就看不到榜单里的演示数据。
 * - showNotif：通知提醒显隐。关掉则「我的」里不出现通知设置入口，也不排程、
 *   不申请通知权限——首发不带这个功能，等要用了再打开，都不用发版。 */
const FEATURES_ID = 'sys_features';

/** 取一个集合里 enabled != false 的全部文档，按 sort 升序；
 * 单集合查询失败给空数组顶上——config 必须尽量返回，App 有内置兜底数据。 */
async function listActive(col: string): Promise<any[]> {
  try {
    const { items } = await getDb().listDocs(col, { limit: LIMIT });
    return items
      .filter((d: any) => d.enabled !== false)
      .sort((a: any, b: any) => (a.sort ?? 0) - (b.sort ?? 0));
  } catch {
    return [];
  }
}

function toPoster(d: any) {
  return { url: String(d.url ?? ''), slogan: String(d.slogan ?? '') };
}

async function fetchMinVersion(): Promise<string> {
  try {
    const { items } = await getDb().listDocs('announcements', {
      where: { _id: MIN_VERSION_ID },
      limit: 1,
    });
    return String(items[0]?.value ?? '');
  } catch {
    return '';
  }
}

/** 功能开关。查不到就按「全开」处理——配置文档还没建过时不能把功能锁死。
 * 注意跟 cleanup 那个开关的兜底方向相反：那个会删数据，读不到就什么都不做；
 * 这里只是显隐，读不到时把功能藏了反而是事故。 */
async function fetchFeatures(): Promise<{ showRank: boolean; showNotif: boolean }> {
  try {
    const { items } = await getDb().listDocs('announcements', {
      where: { _id: FEATURES_ID },
      limit: 1,
    });
    return {
      showRank: items[0]?.showRank !== false,
      showNotif: items[0]?.showNotif !== false,
    };
  } catch {
    return { showRank: true, showNotif: true };
  }
}

export async function getConfig(_req: Req) {
  const [
    presetWishes,
    presetSteps,
    posterTask,
    posterWish,
    posterDone,
    heroImages,
    coverDeclare,
    coverDone,
    achvDefs,
    spots,
    announcements,
    minVersion,
    features,
  ] = await Promise.all([
    listActive('preset_wishes'),
    listActive('preset_steps'),
    listActive('poster_task'),
    listActive('poster_wish'),
    listActive('poster_done'),
    listActive('hero_images'),
    listActive('cover_declare'),
    listActive('cover_done'),
    listActive('achv_defs'),
    listActive('spots'),
    listActive('announcements'),
    fetchMinVersion(),
    fetchFeatures(),
  ]);

  const now = Date.now();
  return ok({
    presetWishes: presetWishes.map((d) => String(d.title ?? '')),
    presetSteps: presetSteps.map((d) => ({
      title: String(d.title ?? ''),
      steps: Array.isArray(d.steps) ? d.steps : [],
    })),
    posters: {
      task: posterTask.map(toPoster),
      wish: posterWish.map(toPoster),
      done: posterDone.map(toPoster),
    },
    heroImages: heroImages.map((d) => String(d.url ?? '')),
    // 分享卡封面：宣告卡（此愿必达，可左右滑）/ 凭证卡（已点亮）
    coverDeclare: coverDeclare.map((d) => String(d.url ?? '')),
    coverDone: coverDone.map((d) => String(d.url ?? '')),
    achvDefs: achvDefs.map((d) => ({
      slug: String(d.slug ?? ''),
      name: String(d.name ?? ''),
      desc: String(d.desc ?? ''),
      icon: String(d.icon ?? ''),
    })),
    spots: spots.map((d) => ({
      name: String(d.name ?? ''),
      lat: Number(d.lat ?? 0),
      lng: Number(d.lng ?? 0),
    })),
    announcements: announcements
      .filter(
        (d) =>
          d._id !== MIN_VERSION_ID &&
          d._id !== FEATURES_ID &&
          (d.startAt ?? -Infinity) <= now &&
          now <= (d.endAt ?? Infinity),
      )
      .map((d) => ({ title: String(d.title ?? ''), body: String(d.body ?? '') })),
    minVersion,
    features,
  });
}
