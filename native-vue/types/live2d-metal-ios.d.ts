declare class Live2DMetalHostView extends UIView {
  static alloc(): Live2DMetalHostView
  initWithFrame(frame: CGRect): Live2DMetalHostView
  setParameterValueForId(value: number, parameterId: string): void
  resetFace(): void
  presentModelImporter(): void
}
