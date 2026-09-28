import { createApp, registerElement } from 'nativescript-vue'
import { Live2DMetalView } from './components/Live2DMetalView.ios'

import Home from './components/Home.vue'

registerElement('Live2DMetalView', () => Live2DMetalView)

createApp(Home).start()
