import { StatusBar } from 'expo-status-bar';
import { useState } from 'react';
import Slider from '@react-native-community/slider';
import {
  Button,
  Platform,
  requireNativeComponent,
  SafeAreaView,
  StyleSheet,
  Text,
  View,
  type ViewProps,
} from 'react-native';

type Live2DMetalProps = ViewProps & {
  angleX: number;
  eyeOpen: number;
  mouthOpen: number;
  importRequest: number;
  resetRequest: number;
};

const NativeLive2DMetal = Platform.OS === 'ios'
  ? requireNativeComponent<Live2DMetalProps>('ExpoLive2DHost')
  : null;

export default function App() {
  const [angleX, setAngleX] = useState(0);
  const [eyeOpen, setEyeOpen] = useState(1);
  const [mouthOpen, setMouthOpen] = useState(0);
  const [importRequest, setImportRequest] = useState(0);
  const [resetRequest, setResetRequest] = useState(0);

  const resetFace = () => {
    setAngleX(0);
    setEyeOpen(1);
    setMouthOpen(0);
    setResetRequest((request) => request + 1);
  };

  if (!NativeLive2DMetal) {
    return (
      <View style={styles.unsupported}>
        <Text style={styles.unsupportedText}>Live2D Metal is available on iOS.</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <NativeLive2DMetal
        style={styles.renderer}
        angleX={angleX}
        eyeOpen={eyeOpen}
        mouthOpen={mouthOpen}
        importRequest={importRequest}
        resetRequest={resetRequest}
      />
      <SafeAreaView pointerEvents="box-none" style={styles.overlay}>
        <View style={styles.toolbar}>
          <View style={styles.action}><Button title="Import model" onPress={() => setImportRequest((request) => request + 1)} /></View>
          <View style={styles.action}><Button title="Reset face" onPress={resetFace} /></View>
        </View>
        <View style={styles.parameters}>
          <Parameter label="Face" value={angleX} onChange={setAngleX} minimum={-30} maximum={30} />
          <Parameter label="Eyes" value={eyeOpen} onChange={setEyeOpen} minimum={0} maximum={1} />
          <Parameter label="Mouth" value={mouthOpen} onChange={setMouthOpen} minimum={0} maximum={1} />
        </View>
      </SafeAreaView>
      <StatusBar style="dark" />
    </View>
  );
}

function Parameter({ label, value, onChange, minimum, maximum }: {
  label: string;
  value: number;
  onChange: (value: number) => void;
  minimum: number;
  maximum: number;
}) {
  return (
    <View style={styles.parameter}>
      <View style={styles.parameterHeader}>
        <Text style={styles.parameterLabel}>{label}</Text>
        <Text style={styles.parameterValue}>{value.toFixed(maximum > 2 ? 0 : 2)}</Text>
      </View>
      <Slider
        minimumValue={minimum}
        maximumValue={maximum}
        value={value}
        onValueChange={onChange}
        minimumTrackTintColor="#2563eb"
        maximumTrackTintColor="#cbd5e1"
        thumbTintColor="#2563eb"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },
  renderer: {
    ...StyleSheet.absoluteFillObject,
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'space-between',
  },
  toolbar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: 12,
  },
  action: {
    backgroundColor: 'rgba(255,255,255,0.9)',
    borderRadius: 8,
    overflow: 'hidden',
  },
  parameters: {
    margin: 12,
    padding: 12,
    backgroundColor: 'rgba(255,255,255,0.92)',
    borderRadius: 8,
    gap: 8,
  },
  parameter: {
    gap: 2,
  },
  parameterHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  parameterLabel: {
    width: 48,
    fontSize: 15,
    color: '#172033',
  },
  parameterValue: {
    textAlign: 'center',
    fontVariant: ['tabular-nums'],
    color: '#172033',
  },
  unsupported: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#f8fafc',
  },
  unsupportedText: {
    color: '#172033',
  },
});
