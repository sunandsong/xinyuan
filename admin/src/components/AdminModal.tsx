import { Modal, type ModalProps } from 'antd';

/** 管理端统一弹窗：居中、分区页眉/页脚、表单区内边距 */
export default function AdminModal({
  children,
  okText = '保存',
  cancelText = '取消',
  width,
  ...props
}: ModalProps) {
  return (
    <Modal
      centered
      className="admin-modal"
      okText={okText}
      cancelText={cancelText}
      width={width ?? 520}
      destroyOnClose
      {...props}
    >
      <div className="admin-form">{children}</div>
    </Modal>
  );
}
