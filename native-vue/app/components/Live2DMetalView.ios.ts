import { Property, View } from '@nativescript/core'

type NativeLive2DMetalView = UIView & {
  setParameterValueForId(value: number, parameterId: string): void
  resetFace(): void
  presentModelImporter(): void
}

declare const Live2DMetalHostView: {
  alloc(): { initWithFrame(frame: CGRect): NativeLive2DMetalView }
}

export class Live2DMetalView extends View {
  createNativeView(): NativeLive2DMetalView {
    return Live2DMetalHostView.alloc().initWithFrame(CGRectZero)
  }

  setParameter(id: string, value: number) {
    (this.nativeViewProtected as NativeLive2DMetalView)?.setParameterValueForId(value, id)
  }

  resetFace() {
    (this.nativeViewProtected as NativeLive2DMetalView)?.resetFace()
  }

  presentModelImporter() {
    (this.nativeViewProtected as NativeLive2DMetalView)?.presentModelImporter()
  }
}

export const modelPathProperty = new Property<Live2DMetalView, string>({
  name: 'modelPath',
  defaultValue: '',
})

modelPathProperty.register(Live2DMetalView)
