import type { ReactNode } from 'react';
import { Switch } from 'antd';

/** 表单字段：标签 + 控件 + 可选说明 */
export function FormField({
  label,
  hint,
  required,
  children,
}: {
  label: string;
  hint?: string;
  required?: boolean;
  children: ReactNode;
}) {
  return (
    <div className="admin-form-field">
      <div className="admin-form-field__label">
        {label}
        {required && <span className="admin-form-field__req">*</span>}
      </div>
      <div className="admin-form-field__control">{children}</div>
      {hint && <div className="admin-form-field__hint">{hint}</div>}
    </div>
  );
}

/** 分组标题（长表单分区用） */
export function FormSection({ title, desc, children }: { title: string; desc?: string; children: ReactNode }) {
  return (
    <section className="admin-form-section">
      <div className="admin-form-section__head">
        <div className="admin-form-section__title">{title}</div>
        {desc && <div className="admin-form-section__desc">{desc}</div>}
      </div>
      <div className="admin-form-section__body">{children}</div>
    </section>
  );
}

/** 两列并排 */
export function FormRow({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={['admin-form-row', className].filter(Boolean).join(' ')}>{children}</div>;
}

/** 开关行：说明在左，开关在右 */
export function FormSwitchRow({
  label,
  hint,
  checked,
  onChange,
}: {
  label: string;
  hint?: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <div className="admin-form-switch">
      <div>
        <div className="admin-form-switch__label">{label}</div>
        {hint && <div className="admin-form-switch__hint">{hint}</div>}
      </div>
      <Switch checked={checked} onChange={onChange} />
    </div>
  );
}

/** 十六进制色值预览（心愿/任务主题色） */
export function ColorInput({
  value,
  onChange,
  placeholder = 'A8B8F8',
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  const hex = value.replace(/^#/, '');
  const swatch = /^[0-9A-Fa-f]{6}$/.test(hex) ? `#${hex}` : '#E6E7EC';
  return (
    <div className="admin-color-input">
      <span className="admin-color-input__swatch" style={{ background: swatch }} />
      <input
        className="admin-color-input__field"
        value={value}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value.replace(/^#/, ''))}
        spellCheck={false}
      />
    </div>
  );
}
