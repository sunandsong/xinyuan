export const DEFAULT_TABLE_PAGE_SIZE = 30;
export const TABLE_PAGE_SIZE_OPTIONS = ['30', '50', '100'] as const;

export interface PaginationBind {
  page: number;
  pageSize: number;
  total: number;
  onChange: (page: number, pageSize: number) => void;
  unit?: string;
}

export function buildPagination(bind: PaginationBind) {
  return {
    current: bind.page,
    pageSize: bind.pageSize,
    total: bind.total,
    showSizeChanger: true,
    pageSizeOptions: [...TABLE_PAGE_SIZE_OPTIONS],
    showTotal: (t: number) => `共 ${t} ${bind.unit ?? '条'}`,
    onChange: bind.onChange,
    style: { padding: '12px 16px', margin: 0 },
  };
}
