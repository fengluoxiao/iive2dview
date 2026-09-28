<template>
  <Frame>
    <Page actionBarHidden="true">
      <GridLayout rows="*, auto">
        <Live2DMetalView
          ref="metalView"
          row="0"
          class="stage"
        />
        <ScrollView row="1" class="controls" height="284">
          <StackLayout>
            <Label class="title" text="Live2D Native" />
            <Label class="subtitle" text="从“文件”导入模型文件夹或 ZIP" />
            <Button class="reset" text="导入模型" @tap="importModel" />
            <GridLayout columns="*, auto" class="control-row">
              <Label class="row-label" col="0" text="脸部左右" />
              <Label class="row-value" col="1" :text="angleX.toFixed(0)" />
            </GridLayout>
            <Slider minValue="-30" maxValue="30" :value="angleX" @valueChange="setAngleX" />
            <GridLayout columns="*, auto" class="control-row">
              <Label class="row-label" col="0" text="睁眼" />
              <Label class="row-value" col="1" :text="eyeOpen.toFixed(2)" />
            </GridLayout>
            <Slider minValue="0" maxValue="1" :value="eyeOpen" @valueChange="setEyeOpen" />
            <GridLayout columns="*, auto" class="control-row">
              <Label class="row-label" col="0" text="张嘴" />
              <Label class="row-value" col="1" :text="mouthOpen.toFixed(2)" />
            </GridLayout>
            <Slider minValue="0" maxValue="1" :value="mouthOpen" @valueChange="setMouthOpen" />
            <Button class="reset" text="复位五官" @tap="resetFace" />
          </StackLayout>
        </ScrollView>
      </GridLayout>
    </Page>
  </Frame>
</template>

<script setup lang="ts">
import { ref } from 'nativescript-vue'
import type { Slider } from '@nativescript/core'
import type { Live2DMetalView } from './Live2DMetalView.ios'

const metalView = ref<Live2DMetalView | null>(null)
const angleX = ref(0)
const eyeOpen = ref(1)
const mouthOpen = ref(0)

function setParameter(id: string, value: number) {
  metalView.value?.setParameter(id, value)
}

function setAngleX(event: { object: Slider }) {
  angleX.value = event.object.value
  setParameter('ParamAngleX', angleX.value)
}

function setEyeOpen(event: { object: Slider }) {
  eyeOpen.value = event.object.value
  setParameter('ParamEyeLOpen', eyeOpen.value)
  setParameter('ParamEyeROpen', eyeOpen.value)
}

function setMouthOpen(event: { object: Slider }) {
  mouthOpen.value = event.object.value
  setParameter('ParamMouthOpenY', mouthOpen.value)
}

function resetFace() {
  angleX.value = 0
  eyeOpen.value = 1
  mouthOpen.value = 0
  metalView.value?.resetFace()
}

function importModel() {
  metalView.value?.presentModelImporter()
}
</script>
