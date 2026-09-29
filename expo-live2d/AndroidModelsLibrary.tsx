import { useCallback, useEffect, useRef, useState } from 'react';
import { AppState, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Directory, Paths } from 'expo-file-system';
import { scanModelDirectory, type DirectoryModel } from './modelDirectory';

export default function AndroidModelsLibrary() {
  const [models, setModels] = useState<DirectoryModel[]>([]);
  const [status, setStatus] = useState('正在创建 models 目录…');
  const [busy, setBusy] = useState(false);
  const scanning = useRef(false);
  const mounted = useRef(true);
  const refresh = useCallback(async () => {
    if (scanning.current) return;
    scanning.current = true; setBusy(true);
    try {
      const root = new Directory(Paths.document, 'models');
      root.create({ intermediates: true, idempotent: true });
      const result = await scanModelDirectory(async relative => {
        // Yield between directories so large model collections do not freeze UI.
        await new Promise(resolve => setTimeout(resolve, 0));
        return new Directory(root, ...relative.split('/').filter(Boolean)).list()
          .map(entry => ({ name: entry.name, directory: entry instanceof Directory }));
      });
      if (mounted.current) {
        setModels(result.models);
        setStatus(result.errors.length ? `找到 ${result.models.length} 个模型，部分目录读取失败：${result.errors[0]}` : `已找到 ${result.models.length} 个模型`);
      }
    } catch (error) { if (mounted.current) setStatus(`扫描失败：${error instanceof Error ? error.message : String(error)}`); }
    finally { scanning.current = false; if (mounted.current) setBusy(false); }
  }, []);
  useEffect(() => {
    mounted.current = true;
    const startup = setTimeout(() => { void refresh(); }, 0);
    const subscription = AppState.addEventListener('change', next => { if (next === 'active') void refresh(); });
    return () => { mounted.current = false; clearTimeout(startup); subscription.remove(); };
  }, [refresh]);
  return <SafeAreaView style={styles.page}><ScrollView contentContainerStyle={styles.content}>
    <Text style={styles.title}>Live2D 模型库</Text>
    <Text style={styles.text}>在支持系统文档存储的文件管理器中，打开侧栏的「Live2D 模型」。这里就是本应用的 models 文件夹。</Text>
    <Text style={styles.text}>把完整模型文件夹复制进去，保留 model3.json、moc3、贴图和动作文件的相对位置。ZIP 请先解压。返回应用后自动扫描，也可以手动刷新。</Text>
    <Pressable accessibilityRole="button" accessibilityLabel="刷新模型" disabled={busy} onPress={() => void refresh()} style={styles.button}><Text style={styles.buttonText}>{busy ? '正在扫描…' : '刷新模型'}</Text></Pressable>
    <Text accessibilityLiveRegion="polite" style={styles.text}>{status}</Text>
    {models.map(model => <View key={model.id} style={styles.card}><Text style={styles.name}>{model.character} · {model.outfit}</Text><Text selectable style={styles.path}>{model.id}</Text></View>)}
    <Text style={styles.text}>Android 当前提供模型目录管理，原生模型预览尚未接入。卸载应用会删除这里的文件，请保留模型备份。</Text>
  </ScrollView></SafeAreaView>;
}
const styles = StyleSheet.create({
  page: { flex: 1, backgroundColor: '#101724' }, content: { padding: 22, gap: 16 },
  title: { color: '#fff', fontSize: 25, fontWeight: '700' }, text: { color: '#bbc8db', fontSize: 15, lineHeight: 23 },
  button: { backgroundColor: '#994e67', padding: 15, borderRadius: 12, alignItems: 'center' },
  buttonText: { color: '#fff', fontWeight: '600' }, card: { backgroundColor: '#1b273b', padding: 14, borderRadius: 12, gap: 7 },
  name: { color: '#fff', fontSize: 16 }, path: { color: '#a7b6cf', fontSize: 12 },
});
