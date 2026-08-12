import { useRef, useState } from 'react';
import { Button, message } from 'antd';
import { UploadOutlined } from '@ant-design/icons';
import { api } from '../api';

/** 选图 → POST /admin/upload 换直传凭证 → PUT 直传 COS → 回稳定链接（去掉 ?sign=）。
 * 图片本体不经过云函数网关（那层限 100KB），流程跟 App 端传心愿照片一致。 */
export default function ImgUpload({ onDone, text = '上传图片' }: { onDone: (url: string) => void; text?: string }) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);

  async function handleFile(file: File) {
    if (file.size > 8 * 1024 * 1024) {
      message.error('图片太大了（>8MB），换一张小的');
      return;
    }
    setUploading(true);
    try {
      const ticket = await api.post('/admin/upload', { mime: file.type || 'image/jpeg' });
      const res = await fetch(ticket.url, {
        method: 'PUT',
        headers: ticket.headers,
        body: file,
      });
      if (!res.ok) throw new Error(`COS PUT ${res.status}`);
      const stable = String(ticket.downloadUrl ?? '').split('?')[0];
      onDone(stable);
      message.success('已上传');
    } catch (e: any) {
      message.error(`上传失败：${e.message ?? e}`);
    } finally {
      setUploading(false);
      if (fileRef.current) fileRef.current.value = '';
    }
  }

  return (
    <>
      <input
        ref={fileRef}
        type="file"
        accept="image/png,image/jpeg,image/webp"
        style={{ display: 'none' }}
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) handleFile(f);
        }}
      />
      <Button icon={<UploadOutlined />} loading={uploading} onClick={() => fileRef.current?.click()}>
        {text}
      </Button>
    </>
  );
}
