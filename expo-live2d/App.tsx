import { StatusBar } from 'expo-status-bar';
import { useCallback, useEffect, useRef, useState } from 'react';
import Slider from '@react-native-community/slider';
import { Platform, Pressable, ScrollView, StyleSheet, Text, View, requireNativeComponent, useWindowDimensions, type NativeSyntheticEvent, type ViewProps } from 'react-native';
import { SafeAreaProvider, useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, { Defs, Path, Pattern, RadialGradient, Rect, Stop } from 'react-native-svg';
import { defaultFace, directionIndex, displayName, emptyState, faceControls, motionLabels, type Direction, type StudioState } from './studio';
import { styles as s } from './studioStyles';

type Command = { type: string; [key: string]: unknown };
type NativeProps = ViewProps & { studioCommand: Command; onStudioEvent: (event: NativeSyntheticEvent<StudioState>) => void };
const NativeStudio = Platform.OS === 'ios' ? requireNativeComponent<NativeProps>('ExpoLive2DHost') : null;
const paths = {
  controls: 'M4 4h16v16H4z M8 8h8 M8 12h5 M8 16h8', export: 'M12 3v12 m-5-5 5 5 5-5 M5 16v5h14v-5',
  reset: 'M3 10a9 9 0 1 1 2 8 M3 4v6h6', mirror: 'M12 3v18 M3 5l6 7-6 7z M21 5l-6 7 6 7z',
  fit: 'M8 3H3v5 M16 3h5v5 M3 16v5h5 M21 16v5h-5', pip: 'M3 4h18v16H3z M11 12h8v6h-8z',
  close: 'M6 6l12 12 M18 6 6 18', play: 'm8 5 11 7-11 7z', brand: 'M3 8h18v13H3z M3 8V3h18v5 M7 3l3 5 M14 3l3 5',
};
function Icon({ name, color = '#a7b6cf', size = 18 }: { name: keyof typeof paths; color?: string; size?: number }) {
  return <Svg width={size} height={size} viewBox="0 0 24 24"><Path d={paths[name]} fill="none" stroke={color} strokeWidth={1.7} strokeLinecap="round" strokeLinejoin="round" /></Svg>;
}
function Action({ label, onPress, selected = false, icon, compact = false, disabled = false }: {
  label: string; onPress: () => void; selected?: boolean; icon?: keyof typeof paths; compact?: boolean; disabled?: boolean;
}) {
  return <Pressable accessibilityRole="button" accessibilityLabel={label} accessibilityState={{ selected, disabled }} disabled={disabled} onPress={onPress}
    style={({ pressed }) => [s.action, selected && s.selected, compact && s.compact, (pressed || disabled) && { opacity: disabled ? 0.4 : 0.7 }]}>
    {icon && <Icon name={icon} color={selected ? '#ffc1cf' : '#a7b6cf'} />}{!compact && <Text numberOfLines={1} style={[s.actionText, selected && s.selectedText]}>{label}</Text>}
  </Pressable>;
}
function Range({ label, value, min, max, onChange, suffix = '' }: { label: string; value: number; min: number; max: number; onChange: (v: number) => void; suffix?: string }) {
  // Slider 5.2 treats a literal zero as an omitted value. Normalize ranges and
  // keep the lower endpoint nonzero so reset and negative ranges stay correct.
  const position = Math.max(0.000001, (value - min) / (max - min));
  const step = max > 3 ? 1 : 0.01;
  const update = (fraction: number) => onChange(Math.max(min, Math.min(max, Number((Math.round((min + fraction * (max - min)) / step) * step).toFixed(2)))));
  return <View style={s.range}><Text style={s.rangeLabel}>{label}</Text><Slider accessibilityLabel={label} style={s.slider} value={position} minimumValue={0} maximumValue={1} step={step / (max - min)} onValueChange={update} minimumTrackTintColor="#e77a91" maximumTrackTintColor="#38445c" thumbTintColor="#f09aab" /><Text style={s.rangeValue}>{value.toFixed(max > 3 ? 0 : 2)}{suffix}</Text></View>;
}
export default function App() { return <SafeAreaProvider><Studio /></SafeAreaProvider>; }
function Studio() {
  const { width, height } = useWindowDimensions(); const insets = useSafeAreaInsets(); const wide = width > 760;
  const [state, setState] = useState(emptyState);
  const [command, setCommand] = useState<Command>({ type: 'initialize', seq: 0 }); const serial = useRef(0);
  const send = useCallback((c: Command) => setCommand({ ...c, seq: ++serial.current }), []);
  const [panel, setPanel] = useState(false); const [tab, setTab] = useState<'motion' | 'expression' | 'face'>('motion');
  const [faces, setFaces] = useState(defaultFace); const [autoplay, setAutoplay] = useState(false);
  const [quality, setQuality] = useState('sharp'); const [expression, setExpression] = useState(-1);
  const [picker, setPicker] = useState<'character' | 'outfit' | null>(null);
  const selected = state.models.find(m => m.id === state.selectedModelId);
  const groups = Object.entries(state.metadata.motions ?? {}).filter(([g, entries]) => !['idle', 'default'].includes(g.toLowerCase()) && entries.length);
  const live = useRef({ state, groups });
  useEffect(() => { live.current = { state, groups }; }, [state, groups]);
  useEffect(() => { const timer = setInterval(() => send({ type: 'state' }), 500); return () => clearInterval(timer); }, [send]);
  useEffect(() => {
    if (!autoplay) return; let cursor = 0;
    const timer = setInterval(() => { const current = live.current; const entry = current.groups[cursor++ % current.groups.length];
      if (entry) send({ type: 'motion', group: entry[0], index: directionIndex(entry[1], current.state.direction) }); }, 3800);
    return () => clearInterval(timer);
  }, [autoplay, send]);
  const receive = useCallback((event: NativeSyntheticEvent<StudioState>) => {
    const next = event.nativeEvent;
    if (next.selectedModelId !== live.current.state.selectedModelId) { setFaces(defaultFace); setExpression(-1); setAutoplay(false); }
    setExpression(next.expressionIndex);
    setState(next);
  }, []);
  const reset = () => { setFaces(defaultFace); setAutoplay(false); setExpression(-1); send({ type: 'reset' }); };
  const controls = <>
    <View style={s.section}><Text style={s.sectionLabel}>模型</Text>
      <View style={s.modelCard}><View style={s.modelMark}><Text style={s.markText}>{displayName(selected?.character ?? 'L').slice(0, 1)}</Text></View><View style={{ flex: 1 }}><Text style={s.modelName}>{displayName(selected?.character ?? '导入模型')}</Text><Text style={s.modelOutfit}>{displayName(selected?.outfit ?? '文件夹 / ZIP')}</Text></View><View style={s.dot} /></View>
      <View style={s.row}><Action label={displayName(selected?.character ?? '选择角色')} onPress={() => setPicker(picker === 'character' ? null : 'character')} /><Action label={displayName(selected?.outfit ?? '选择服装')} onPress={() => setPicker(picker === 'outfit' ? null : 'outfit')} /></View>
      {picker && <View style={s.selectionList}>{state.models.filter((m, i, all) => picker === 'character' ? all.findIndex(a => a.character === m.character) === i : m.character === selected?.character).map(m => <Action key={m.id} label={displayName(picker === 'character' ? m.character : m.outfit)} selected={m.id === selected?.id} onPress={() => { send({ type: 'selectModel', id: m.id }); setPicker(null); }} />)}</View>}
      <View style={s.row}><Action label="导入文件夹" onPress={() => { setPanel(false); send({ type: 'importFolder' }); }} /><Action label="导入 ZIP" onPress={() => { setPanel(false); send({ type: 'importZip' }); }} /></View>
    </View>
    <View style={s.section}><Text style={s.sectionLabel}>视图</Text><Range label="缩放" min={0.45} max={2.4} value={state.view.scale} suffix="x" onChange={value => send({ type: 'scale', value })} />
      <View style={s.row}><Action compact icon="mirror" label="水平镜像" selected={state.view.mirrored} onPress={() => send({ type: 'mirror', value: !state.view.mirrored })} /><Action compact icon="fit" label="复位位置，保留缩放" onPress={reset} /><Action compact icon="export" label="导出 PNG" onPress={() => send({ type: 'export' })} /></View>
      <View style={s.segments}>{[['auto', '自动'], ['smooth', '流畅'], ['sharp', '高清']].map(([id, label]) => <Pressable key={id} accessibilityRole="button" onPress={() => { setQuality(id); send({ type: 'quality', value: id }); }} style={[s.segment, quality === id && s.segmentActive]}><Text style={[s.segmentText, quality === id && s.activeText]}>{label}</Text></Pressable>)}</View>
    </View>
    <View style={[s.section, { paddingBottom: 20 }]}><View style={s.segments}>{(['motion', 'expression', 'face'] as const).map((id, i) => <Pressable key={id} accessibilityRole="tab" accessibilityState={{ selected: tab === id }} onPress={() => setTab(id)} style={[s.segment, tab === id && s.segmentActive]}><Text style={[s.segmentText, tab === id && s.activeText]}>{['动作', '表情', '五官'][i]}</Text></Pressable>)}</View>
      {tab === 'motion' && <View style={s.grid}>{groups.map(([group, entries]) => <View key={group} style={s.gridHalf}><Action icon="play" label={`${motionLabels[group.toLowerCase()] ?? group}  ${entries.length}`} onPress={() => send({ type: 'motion', group, index: directionIndex(entries, state.direction) })} /></View>)}<View style={s.gridHalf}><Action selected={autoplay} label={autoplay ? '■ 停止演示' : '✧ 自动演示'} disabled={!groups.length} onPress={() => setAutoplay(!autoplay)} /></View>{!groups.length && <Text style={s.empty}>此模型暂无可演示动作</Text>}</View>}
      {tab === 'expression' && <View style={s.grid}><View style={s.gridThird}><Action selected={expression === -1} label="无" onPress={() => { setExpression(-1); send({ type: 'expression', index: -1 }); }} /></View>{(state.metadata.expressions ?? []).map((e, index) => <View key={`${e.Name}-${index}`} style={s.gridThird}><Action selected={expression === index} label={(e.Name ?? `表情 ${index + 1}`).replace(/^exp_/, '').replace(/\d+$/, '')} onPress={() => { setExpression(index); send({ type: 'expression', index }); }} /></View>)}</View>}
      {tab === 'face' && <View style={{ paddingTop: 10 }}>{faceControls.map(c => <Range key={c.key} label={c.label} min={c.min} max={c.max} value={faces[c.key]} onChange={value => { setFaces(f => ({ ...f, [c.key]: value })); send({ type: 'parameter', ids: c.ids, value }); }} />)}<View style={s.row}><Action selected={state.blink} label={state.blink ? '眨眼已开启' : '眨眼已关闭'} onPress={() => send({ type: 'blink', value: !state.blink })} /><Action label="复位五官" onPress={() => { setFaces(defaultFace); send({ type: 'resetFace' }); }} /></View></View>}
    </View>
  </>;
  return <View style={[s.root, { paddingTop: insets.top, paddingLeft: insets.left, paddingRight: insets.right }]}><StatusBar style="light" />
    {wide && <View style={s.sidebar}><View style={s.brand}><View style={s.brandIcon}><Icon name="brand" color="white" /></View><Text style={s.brandTitle}>Live2D <Text style={s.muted}>Studio</Text></Text></View><ScrollView>{controls}</ScrollView><Text style={s.sidebarFooter}>{state.view.gpu} · Metal</Text></View>}
    <View style={s.workspace}><View style={s.topbar}>{!wide && <View style={s.mobileTitle}><Text numberOfLines={1} style={s.title}>{displayName(selected?.character ?? 'Live2D')}</Text><Text style={s.subtitle}>Live2D Studio</Text></View>}<View style={s.directions}>{(['C', 'L', 'R'] as Direction[]).map((d, i) => <Pressable accessibilityRole="button" accessibilityState={{ selected: state.direction === d }} key={d} onPress={() => send({ type: 'direction', value: d })} style={[s.direction, state.direction === d && s.segmentActive]}><Text style={[s.directionText, state.direction === d && s.activeText]}>{['正面', '左侧面', '右侧面'][i]}</Text></Pressable>)}</View>{wide && <Text style={s.badge}>GPU · Metal</Text>}<Pressable accessibilityLabel="画中画" onPress={() => send({ type: 'pip' })} style={s.pip}><Icon name="pip" color="white" size={16} /><Text style={s.pipText}>画中画</Text></Pressable></View>
      <View style={s.stage}><Svg pointerEvents="none" style={StyleSheet.absoluteFill} width="100%" height="100%"><Defs><RadialGradient id="bg" cx="50%" cy="35%" rx="70%" ry="70%"><Stop offset="0" stopColor="#1b273b" /><Stop offset="0.65" stopColor="#101724" /><Stop offset="1" stopColor="#0b0e16" /></RadialGradient><Pattern id="grid" width={28} height={28} patternUnits="userSpaceOnUse"><Path d="M0 28V0H28" fill="none" stroke="#829cc2" strokeOpacity={0.04} /></Pattern></Defs><Rect width="100%" height="100%" fill="url(#bg)" /><Rect width="100%" height="100%" fill="url(#grid)" /></Svg>
        {NativeStudio && <NativeStudio style={StyleSheet.absoluteFill} studioCommand={command} onStudioEvent={receive} />}
        <Text pointerEvents="none" style={s.stageHint}>拖动平移 · 双指缩放</Text><View pointerEvents="none" style={s.hud}><Text style={s.fps}>{Math.round(state.view.fps) || '--'} <Text style={s.hudText}>/ 60 FPS</Text></Text><Text style={s.hudText}>原生 Metal</Text><Text style={s.hudText}>更新与提交 {state.view.updateMs.toFixed(1)} ms</Text><Text style={s.hudText}>{state.view.pixelWidth} × {state.view.pixelHeight}</Text><Text style={s.hudText}>{state.metadata.drawables ?? 0} DRAWABLES</Text></View>
        {!selected && <View pointerEvents="none" style={s.welcome}><Icon name="brand" size={38} color="#ec738a" /><Text style={s.welcomeTitle}>你的 Live2D 工作室</Text><Text style={s.muted}>打开控制台，导入模型开始创作</Text></View>}<View pointerEvents="none" style={s.toast}><View style={s.dot} /><Text style={s.toastText}>{state.status}</Text></View>
      </View>
      {!wide && <View style={[s.dock, { paddingBottom: Math.max(8, insets.bottom) }]}>{(['controls', 'export', 'reset'] as const).map((icon, i) => <Pressable key={icon} accessibilityRole="button" onPress={() => i === 0 ? setPanel(true) : i === 1 ? send({ type: 'export' }) : reset()} style={s.dockButton}><Icon name={icon} color={i === 0 ? '#f39bad' : '#91a0ba'} size={20} /><Text style={[s.dockText, i === 0 && { color: '#f39bad' }]}>{['控制台', '导出', '复位'][i]}</Text></Pressable>)}</View>}
    </View>
    {panel && !wide && <View style={s.backdrop}><Pressable accessibilityLabel="关闭控制台" style={StyleSheet.absoluteFill} onPress={() => setPanel(false)} /><View style={[s.sheet, { maxHeight: Math.min(height * 0.76, 620), paddingBottom: Math.max(17, insets.bottom) }]}><View style={s.sheetHead}><View style={s.grabber} /><Pressable accessibilityLabel="关闭控制台" onPress={() => setPanel(false)} style={s.close}><Icon name="close" /></Pressable></View><ScrollView keyboardShouldPersistTaps="handled">{controls}</ScrollView></View></View>}
  </View>;
}
