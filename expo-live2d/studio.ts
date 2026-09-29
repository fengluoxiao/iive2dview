export type Direction = 'C' | 'L' | 'R';
export type Motion = { Name?: string; File?: string };
export type Model = { id: string; character: string; outfit: string };
export type StudioState = {
  models: Model[]; selectedModelId: string; status: string; direction: Direction; blink: boolean; expressionIndex: number;
  metadata: { motions?: Record<string, Motion[]>; expressions?: Motion[]; drawables?: number };
  view: { scale: number; mirrored: boolean; fps: number; updateMs: number; pixelWidth: number; pixelHeight: number; gpu: string };
};
export const emptyState: StudioState = {
  models: [], selectedModelId: '', status: '导入文件夹或 ZIP，开始预览', direction: 'C', blink: true, expressionIndex: -1, metadata: {},
  view: { scale: 1, mirrored: false, fps: 0, updateMs: 0, pixelWidth: 0, pixelHeight: 0, gpu: 'Metal' },
};
export const faceControls = [
  { key: 'angleX', label: '脸部左右', ids: ['ParamAngleX'], min: -30, max: 30, initial: 0 },
  { key: 'angleY', label: '脸部上下', ids: ['ParamAngleY'], min: -30, max: 30, initial: 0 },
  { key: 'angleZ', label: '头部倾斜', ids: ['ParamAngleZ'], min: -30, max: 30, initial: 0 },
  { key: 'eyeX', label: '眼球左右', ids: ['ParamEyeBallX'], min: -1, max: 1, initial: 0 },
  { key: 'eyeY', label: '眼球上下', ids: ['ParamEyeBallY'], min: -1, max: 1, initial: 0 },
  { key: 'eyeOpen', label: '睁眼', ids: ['ParamEyeLOpen', 'ParamEyeROpen'], min: 0, max: 1, initial: 1 },
  { key: 'brow', label: '眉形', ids: ['ParamBrowLForm', 'ParamBrowRForm'], min: -1, max: 1, initial: 0 },
  { key: 'mouthForm', label: '嘴型', ids: ['ParamMouthForm'], min: -1, max: 1, initial: 0 },
  { key: 'mouthOpen', label: '张嘴', ids: ['ParamMouthOpenY'], min: 0, max: 1, initial: 0 },
] as const;
export const defaultFace = Object.fromEntries(faceControls.map(c => [c.key, c.initial])) as Record<string, number>;
export const motionLabels: Record<string, string> = {
  smile: '微笑', nod: '点头', look: '注视', thinking: '思考', question: '疑问', bye: '挥手', serious: '认真',
  angry: '生气', sad: '难过', surprised: '惊讶', cry: '哭泣', kime: '决定', denial: '否认', check: '确认', maskoff: '摘面具', idle: '待机',
};
export function directionIndex(entries: Motion[], direction: Direction): number {
  const index = entries.findIndex(e => (e.Name ?? e.File?.replace(/\.motion3\.json$/i, '') ?? '').endsWith(`_${direction}`));
  return Math.max(0, index);
}
export function displayName(value: string): string { return value.replaceAll('_', ' ').replace(/\b\w/g, s => s.toUpperCase()); }
