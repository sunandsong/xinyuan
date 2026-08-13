import { DatePicker, Input, InputNumber } from 'antd';
import dayjs, { type Dayjs } from 'dayjs';
import type { CrudEditForm } from './components/CrudTable';
import { ColorInput, FormField, FormRow, FormSection, FormSwitchRow } from './components/AdminForm';
import MapPicker from './components/MapPicker';

type FormProps<V> = { values: V; onChange: (patch: Partial<V>) => void };

function parseSteps(text: string, existing?: Array<{ id: string; title: string; done: boolean; doneAt: number | null }>) {
  return text
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line, i) => {
      const done = /^x\s+/i.test(line);
      const title = line.replace(/^x\s+/i, '');
      const old = existing?.[i];
      return {
        id: old?.id ?? `step-${i}-${Date.now()}`,
        title,
        done,
        doneAt: done ? (old?.doneAt ?? Date.now()) : null,
      };
    });
}

function stepsToText(steps?: Array<{ title: string; done: boolean }>) {
  return (steps ?? []).map((s) => (s.done ? `x ${s.title}` : s.title)).join('\n');
}

// —— 默认清单 ——
interface PresetWishForm {
  title: string;
  sort: number;
  enabled: boolean;
}

export const presetWishForm: CrudEditForm<PresetWishForm> = {
  modalTitle: ({ isNew }) => (isNew ? '新建清单项' : '编辑清单项'),
  width: 480,
  defaults: (_ctx) => ({ title: '', sort: 999, enabled: true }),
  fromRow: (row, _ctx) => ({
    title: String(row?.title ?? ''),
    sort: Number(row?.sort ?? 999),
    enabled: row?.enabled !== false,
  }),
  validate: (v) => (!v.title.trim() ? '标题不能为空' : null),
  toDoc: (v) => ({ title: v.title.trim(), sort: v.sort, enabled: v.enabled }),
  Form: ({ values, onChange }: FormProps<PresetWishForm>) => (
    <>
      <FormField label="标题" required>
        <Input
          placeholder="如：看一次日出"
          value={values.title}
          onChange={(e) => onChange({ title: e.target.value })}
        />
      </FormField>
      <FormField label="排序" hint="数字越小越靠前">
        <InputNumber style={{ width: '100%' }} value={values.sort} onChange={(n) => onChange({ sort: n ?? 0 })} />
      </FormField>
      <FormSwitchRow label="启用" hint="关闭后 App 不再拉取此项" checked={values.enabled} onChange={(enabled) => onChange({ enabled })} />
    </>
  ),
};

// —— 景点 ——
interface SpotForm {
  name: string;
  province: string;
  lat: number;
  lng: number;
  sort: number;
  enabled: boolean;
}

export const spotForm: CrudEditForm<SpotForm> = {
  modalTitle: ({ isNew }) => (isNew ? '新建景点' : '编辑景点'),
  width: 680,
  defaults: (_ctx) => ({ name: '', province: '', lat: 0, lng: 0, sort: 999, enabled: true }),
  fromRow: (row, _ctx) => ({
    name: String(row?.name ?? ''),
    province: String(row?.province ?? ''),
    lat: Number(row?.lat ?? 0),
    lng: Number(row?.lng ?? 0),
    sort: Number(row?.sort ?? 999),
    enabled: row?.enabled !== false,
  }),
  validate: (v) => (!v.name.trim() ? '景点名称不能为空' : null),
  toDoc: (v) => ({
    name: v.name.trim(),
    province: v.province.trim(),
    lat: v.lat,
    lng: v.lng,
    sort: v.sort,
    enabled: v.enabled,
  }),
  Form: ({ values, onChange }: FormProps<SpotForm>) => (
    <>
      <FormSection title="基本信息">
        <FormField label="景点名称" required>
          <Input value={values.name} onChange={(e) => onChange({ name: e.target.value })} placeholder="如：故宫" />
        </FormField>
        <FormField label="省份" hint="地图选点后会自动填充，也可手改">
          <Input value={values.province} onChange={(e) => onChange({ province: e.target.value })} placeholder="如：北京" />
        </FormField>
      </FormSection>
      <FormSection title="地图定位" desc="搜索景点或在地图上点击、拖动标记">
        <MapPicker
          lat={values.lat}
          lng={values.lng}
          onChange={(patch) => {
            onChange({
              lat: patch.lat,
              lng: patch.lng,
              ...(patch.province ? { province: patch.province } : {}),
              ...(patch.name && !values.name.trim() ? { name: patch.name } : {}),
            });
          }}
        />
      </FormSection>
      <FormSection title="发布设置">
        <FormField label="排序">
          <InputNumber style={{ width: '100%' }} value={values.sort} onChange={(n) => onChange({ sort: n ?? 0 })} />
        </FormField>
        <FormSwitchRow label="启用" checked={values.enabled} onChange={(enabled) => onChange({ enabled })} />
      </FormSection>
    </>
  ),
};

// —— 心愿 ——
interface WishForm {
  title: string;
  desc: string;
  color: string;
  done: boolean;
  location: string;
  quote: string;
  targetAt: Dayjs | null;
  stepsText: string;
  photosText: string;
}

export const wishForm: CrudEditForm<WishForm> = {
  modalTitle: ({ isNew }) => (isNew ? '新建心愿' : '编辑心愿'),
  width: 600,
  defaults: (_ctx) => ({
    title: '',
    desc: '',
    color: 'A8B8F8',
    done: false,
    location: '',
    quote: '',
    targetAt: null,
    stepsText: '',
    photosText: '',
  }),
  fromRow: (row, _ctx) => ({
    title: String(row?.title ?? ''),
    desc: String(row?.desc ?? ''),
    color: String(row?.color ?? 'A8B8F8'),
    done: Boolean(row?.done),
    location: String(row?.location ?? ''),
    quote: String(row?.quote ?? ''),
    targetAt: row?.targetAt ? dayjs(Number(row.targetAt)) : null,
    stepsText: stepsToText(row?.steps as Array<{ title: string; done: boolean }> | undefined),
    photosText: ((row?.photos as string[]) ?? []).join('\n'),
  }),
  validate: (v) => (!v.title.trim() ? '标题不能为空' : null),
  toDoc: (v, row, ctx) => ({
    title: v.title.trim(),
    desc: v.desc.trim() || null,
    color: v.color.trim() || 'A8B8F8',
    done: v.done,
    doneAt: v.done ? Number(row?.doneAt ?? Date.now()) : null,
    location: v.location.trim() || null,
    quote: v.quote.trim() || null,
    targetAt: v.targetAt ? v.targetAt.valueOf() : null,
    steps: parseSteps(v.stepsText, row?.steps as any),
    photos: v.photosText
      .split('\n')
      .map((s) => s.trim())
      .filter(Boolean),
    notes: row?.notes ?? [],
    uid: row?.uid ?? ctx.where.uid,
  }),
  Form: ({ values, onChange }: FormProps<WishForm>) => (
    <>
      <FormSection title="心愿内容">
        <FormField label="标题" required>
          <Input value={values.title} onChange={(e) => onChange({ title: e.target.value })} />
        </FormField>
        <FormField label="描述">
          <Input.TextArea rows={3} value={values.desc} onChange={(e) => onChange({ desc: e.target.value })} placeholder="补充说明（可选）" />
        </FormField>
        <FormRow>
          <FormField label="主题色" hint="六位十六进制，不含 #">
            <ColorInput value={values.color} onChange={(color) => onChange({ color })} />
          </FormField>
          <FormField label="目标日期">
            <DatePicker value={values.targetAt} onChange={(d) => onChange({ targetAt: d })} style={{ width: '100%' }} placeholder="可选" />
          </FormField>
        </FormRow>
        <FormSwitchRow label="已实现" checked={values.done} onChange={(done) => onChange({ done })} />
      </FormSection>
      <FormSection title="实现记录">
        <FormField label="实现地点">
          <Input value={values.location} onChange={(e) => onChange({ location: e.target.value })} placeholder="如：杭州" />
        </FormField>
        <FormField label="实现语录">
          <Input value={values.quote} onChange={(e) => onChange({ quote: e.target.value })} placeholder="完成时的一句话" />
        </FormField>
      </FormSection>
      <FormSection title="里程碑与照片">
        <FormField label="里程碑" hint="一行一步；已完成的行前加 x 和空格">
          <Input.TextArea rows={4} value={values.stepsText} onChange={(e) => onChange({ stepsText: e.target.value })} />
        </FormField>
        <FormField label="照片链接" hint="一行一个 URL">
          <Input.TextArea rows={3} value={values.photosText} onChange={(e) => onChange({ photosText: e.target.value })} />
        </FormField>
      </FormSection>
    </>
  ),
};

// —— 任务 ——
interface TaskForm {
  title: string;
  day: Dayjs;
  done: boolean;
  wishId: string;
  desc: string;
  color: string;
}

export const taskForm: CrudEditForm<TaskForm> = {
  modalTitle: ({ isNew }) => (isNew ? '新建任务' : '编辑任务'),
  width: 560,
  defaults: (_ctx) => ({
    title: '',
    day: dayjs(),
    done: false,
    wishId: '',
    desc: '',
    color: '',
  }),
  fromRow: (row, _ctx) => ({
    title: String(row?.title ?? ''),
    day: row?.day ? dayjs(String(row.day), 'YYYY-MM-DD') : dayjs(),
    done: Boolean(row?.done),
    wishId: String(row?.wishId ?? ''),
    desc: String(row?.desc ?? ''),
    color: String(row?.color ?? ''),
  }),
  validate: (v) => (!v.title.trim() ? '标题不能为空' : null),
  toDoc: (v, row, ctx) => ({
    title: v.title.trim(),
    day: v.day.format('YYYY-MM-DD'),
    done: v.done,
    wishId: v.wishId.trim() || null,
    desc: v.desc.trim() || null,
    color: v.color.trim() || row?.color || 'A8B8F8',
    remind: row?.remind ?? false,
    uid: row?.uid ?? ctx.where.uid,
  }),
  Form: ({ values, onChange }: FormProps<TaskForm>) => (
    <>
      <FormField label="标题" required>
        <Input value={values.title} onChange={(e) => onChange({ title: e.target.value })} />
      </FormField>
      <FormRow>
        <FormField label="日期">
          <DatePicker value={values.day} onChange={(d) => d && onChange({ day: d })} style={{ width: '100%' }} />
        </FormField>
        <FormField label="主题色" hint="可留空">
          <ColorInput value={values.color} onChange={(color) => onChange({ color })} />
        </FormField>
      </FormRow>
      <FormSwitchRow label="已完成" checked={values.done} onChange={(done) => onChange({ done })} />
      <FormField label="所属心愿 ID" hint="杂事任务可留空">
        <Input value={values.wishId} onChange={(e) => onChange({ wishId: e.target.value })} placeholder="关联心愿的 _id" />
      </FormField>
      <FormField label="描述">
        <Input.TextArea rows={3} value={values.desc} onChange={(e) => onChange({ desc: e.target.value })} />
      </FormField>
    </>
  ),
};

// —— 时光胶囊 ——
interface LetterForm {
  title: string;
  content: string;
  openAt: Dayjs;
}

export const letterForm: CrudEditForm<LetterForm> = {
  modalTitle: ({ isNew }) => (isNew ? '新建胶囊' : '编辑胶囊'),
  width: 560,
  defaults: (_ctx) => ({
    title: '',
    content: '',
    openAt: dayjs().add(1, 'year'),
  }),
  fromRow: (row, _ctx) => ({
    title: String(row?.title ?? ''),
    content: String(row?.content ?? ''),
    openAt: row?.openAt ? dayjs(Number(row.openAt)) : dayjs().add(1, 'year'),
  }),
  validate: (v) => {
    if (!v.title.trim()) return '标题不能为空';
    if (!v.content.trim()) return '正文不能为空';
    return null;
  },
  toDoc: (v, row, ctx) => ({
    title: v.title.trim(),
    content: v.content,
    openAt: v.openAt.valueOf(),
    uid: row?.uid ?? ctx.where.uid,
  }),
  Form: ({ values, onChange }: FormProps<LetterForm>) => (
    <>
      <FormField label="标题" required>
        <Input value={values.title} onChange={(e) => onChange({ title: e.target.value })} />
      </FormField>
      <FormField label="正文" required>
        <Input.TextArea rows={8} value={values.content} onChange={(e) => onChange({ content: e.target.value })} placeholder="写给未来的自己…" />
      </FormField>
      <FormField label="开启时间" hint="到达此时间后用户才能拆开">
        <DatePicker showTime value={values.openAt} onChange={(d) => d && onChange({ openAt: d })} style={{ width: '100%' }} />
      </FormField>
    </>
  ),
};
