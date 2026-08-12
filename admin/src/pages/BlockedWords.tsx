import { useCallback, useEffect, useState } from 'react';
import { Alert, Card, Input, Spin, Tag, message } from 'antd';
import { api } from '../api';

interface WordDoc {
  _id: string;
  word: string;
}

/** 屏蔽词（blockwords）：命中就挡心愿标题上榜、昵称对外脱敏。百级数据量，一次拉全。 */
export default function BlockedWords() {
  const [words, setWords] = useState<WordDoc[] | null>(null);
  const [adding, setAdding] = useState(false);

  const load = useCallback(() => {
    api
      .get('/admin/content/blockwords?limit=100')
      .then((d) => setWords(d.items))
      .catch((e) => message.error(`加载失败：${e.message}`));
  }, []);

  useEffect(load, [load]);

  async function add(word: string) {
    const w = word.trim();
    if (!w) return;
    if (words?.some((d) => d.word === w)) {
      message.warning('已经有这个词了');
      return;
    }
    setAdding(true);
    try {
      await api.post('/admin/content/blockwords', { doc: { word: w } });
      message.success('已添加');
      load();
    } catch (e: any) {
      message.error(`添加失败：${e.message}`);
    } finally {
      setAdding(false);
    }
  }

  async function remove(doc: WordDoc) {
    try {
      await api.post('/admin/content/blockwords/delete', { id: doc._id });
      message.success('已删除');
      load();
    } catch (e: any) {
      message.error(`删除失败：${e.message}`);
    }
  }

  return (
    <div style={{ padding: 24 }}>
      <Alert
        type="info"
        showIcon
        style={{ marginBottom: 16 }}
        message="包含式匹配：心愿标题含屏蔽词就不进热度榜；昵称含屏蔽词对外显示为「用户xxxx」。"
      />
      <Card size="small" title={`屏蔽词（${words?.length ?? '…'}）`}>
        {words === null ? (
          <Spin />
        ) : (
          <>
            <div style={{ marginBottom: 12 }}>
              {words.map((d) => (
                <Tag
                  key={d._id}
                  closable
                  onClose={(e) => {
                    e.preventDefault();
                    remove(d);
                  }}
                  style={{ marginBottom: 8 }}
                >
                  {d.word}
                </Tag>
              ))}
              {words.length === 0 && <span style={{ color: '#999' }}>还没有屏蔽词</span>}
            </div>
            <Input.Search
              placeholder="输入新屏蔽词，回车添加"
              enterButton="添加"
              loading={adding}
              style={{ maxWidth: 360 }}
              onSearch={(v, e) => {
                add(v);
                if (e?.target) (e.target as HTMLInputElement).value = '';
              }}
            />
          </>
        )}
      </Card>
    </div>
  );
}
