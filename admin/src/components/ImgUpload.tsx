import { useRef, useState } from 'react';
import { Button, message } from 'antd';
import { UploadOutlined } from '@ant-design/icons';
import { api } from '../api';
import { readImageSize } from '../imageCrop';
import ImageCropModal, { type CropSpec } from './ImageCropModal';

/** 各场景推荐尺寸（跟 App 海报 3:4、头图宽屏等对齐） */
export const CROP_PRESETS = {
  poster: {
    aspect: 3 / 4,
    hint: '海报建议 900×1200（3:4），超出会自动提示裁剪',
    outputWidth: 900,
    outputHeight: 1200,
  },
  hero: {
    aspect: 16 / 9,
    hint: '首页大图建议 1280×720（16:9），超出会自动提示裁剪',
    outputWidth: 1280,
    outputHeight: 720,
  },
  icon: {
    aspect: 1,
    hint: '勋章图标建议 256×256（正方形）',
    outputWidth: 256,
    outputHeight: 256,
  },
  avatar: {
    aspect: 1,
    hint: '头像建议 512×512（正方形）',
    outputWidth: 512,
    outputHeight: 512,
  },
} satisfies Record<string, CropSpec>;

export type CropPreset = keyof typeof CROP_PRESETS;

/** 选图 → 裁剪弹窗（拖动/缩放）→ 压缩 → 直传 COS → 回稳定链接 */
export default function ImgUpload({
  onDone,
  text = '上传图片',
  preset = 'poster',
}: {
  onDone: (url: string) => void;
  text?: string;
  preset?: CropPreset;
}) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [cropOpen, setCropOpen] = useState(false);
  const [pendingFile, setPendingFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [sourceSize, setSourceSize] = useState<{ width: number; height: number } | null>(null);

  const spec = CROP_PRESETS[preset];

  function resetPicker() {
    if (fileRef.current) fileRef.current.value = '';
  }

  function closeCrop() {
    setCropOpen(false);
    setPendingFile(null);
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewUrl(null);
    setSourceSize(null);
    resetPicker();
  }

  async function onFilePicked(file: File) {
    if (file.size > 8 * 1024 * 1024) {
      message.error('原图不能超过 8MB，请换一张小的');
      resetPicker();
      return;
    }
    try {
      const size = await readImageSize(file);
      setSourceSize(size);
      const url = URL.createObjectURL(file);
      setPendingFile(file);
      setPreviewUrl(url);
      setCropOpen(true);
    } catch (e: any) {
      message.error(e.message ?? '无法读取图片');
      resetPicker();
    }
  }

  async function uploadBlob(blob: Blob) {
    setUploading(true);
    try {
      const ticket = await api.post('/admin/upload', { mime: 'image/jpeg' });
      const res = await fetch(ticket.url, {
        method: 'PUT',
        headers: ticket.headers,
        body: blob,
      });
      if (!res.ok) throw new Error(`COS PUT ${res.status}`);
      const stable = String(ticket.downloadUrl ?? '').split('?')[0];
      onDone(stable);
      message.success('已上传');
      closeCrop();
    } catch (e: any) {
      message.error(`上传失败：${e.message ?? e}`);
    } finally {
      setUploading(false);
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
          if (f) onFilePicked(f);
        }}
      />
      <Button icon={<UploadOutlined />} loading={uploading} onClick={() => fileRef.current?.click()}>
        {text}
      </Button>
      <ImageCropModal
        open={cropOpen}
        imageSrc={previewUrl}
        fileName={pendingFile?.name ?? ''}
        spec={spec}
        sourceSize={sourceSize}
        onCancel={closeCrop}
        onConfirm={uploadBlob}
      />
    </>
  );
}
