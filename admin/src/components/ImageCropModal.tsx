import { useCallback, useEffect, useState } from 'react';
import { Alert, Slider, Typography } from 'antd';
import AdminModal from './AdminModal';
import Cropper, { type Area } from 'react-easy-crop';
import { getCroppedBlob } from '../imageCrop';

export interface CropSpec {
  aspect: number;
  hint: string;
  outputWidth: number;
  outputHeight: number;
}

export default function ImageCropModal({
  open,
  imageSrc,
  fileName,
  spec,
  sourceSize,
  onCancel,
  onConfirm,
}: {
  open: boolean;
  imageSrc: string | null;
  fileName: string;
  spec: CropSpec;
  sourceSize: { width: number; height: number } | null;
  onCancel: () => void;
  onConfirm: (blob: Blob) => void;
}) {
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedArea, setCroppedArea] = useState<Area | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!open) return;
    setCrop({ x: 0, y: 0 });
    setZoom(1);
    setCroppedArea(null);
  }, [open, imageSrc]);

  const onCropComplete = useCallback((_: Area, pixels: Area) => {
    setCroppedArea(pixels);
  }, []);

  async function handleOk() {
    if (!imageSrc || !croppedArea) return;
    setSubmitting(true);
    try {
      const blob = await getCroppedBlob(
        imageSrc,
        croppedArea,
        spec.outputWidth,
        spec.outputHeight,
      );
      onConfirm(blob);
    } finally {
      setSubmitting(false);
    }
  }

  const oversize =
    sourceSize &&
    (sourceSize.width > spec.outputWidth * 1.2 || sourceSize.height > spec.outputHeight * 1.2);

  return (
    <AdminModal
      title="裁剪图片"
      open={open}
      onCancel={onCancel}
      onOk={handleOk}
      okText="确认上传"
      confirmLoading={submitting}
      width={560}
    >
      <Alert type="info" showIcon message={spec.hint} style={{ marginBottom: 12 }} />
      {oversize && sourceSize && (
        <Alert
          type="warning"
          showIcon
          style={{ marginBottom: 12 }}
          message={`原图 ${sourceSize.width}×${sourceSize.height}，将裁剪并压缩为 ${spec.outputWidth}×${spec.outputHeight}`}
        />
      )}
      {imageSrc && (
        <>
          <div
            style={{
              position: 'relative',
              height: 360,
              background: '#1a1a1a',
              borderRadius: 8,
              overflow: 'hidden',
            }}
          >
            <Cropper
              image={imageSrc}
              crop={crop}
              zoom={zoom}
              aspect={spec.aspect}
              onCropChange={setCrop}
              onZoomChange={setZoom}
              onCropComplete={onCropComplete}
            />
          </div>
          <div style={{ marginTop: 16 }}>
            <Typography.Text type="secondary">缩放</Typography.Text>
            <Slider min={1} max={3} step={0.02} value={zoom} onChange={setZoom} />
            <Typography.Text type="secondary" style={{ fontSize: 12 }}>
              拖动图片调整位置，滑块放大缩小
            </Typography.Text>
          </div>
        </>
      )}
      {!imageSrc && <Typography.Text type="secondary">正在加载 {fileName}…</Typography.Text>}
    </AdminModal>
  );
}
