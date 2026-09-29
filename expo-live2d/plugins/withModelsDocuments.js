const { withAndroidManifest, withDangerousMod } = require('@expo/config-plugins');
const fs = require('node:fs/promises');
const path = require('node:path');

module.exports = function withModelsDocuments(config) {
  config = withAndroidManifest(config, c => {
    const application = c.modResults.manifest.application[0];
    const providerName = 'com.fengluo.live2dmodels.ModelsDocumentsProvider';
    application.provider = (application.provider || []).filter(p => p.$['android:name'] !== providerName);
    application.provider.push({
      $: {
        'android:name': providerName,
        'android:authorities': '${applicationId}.models.documents',
        'android:exported': 'true',
        'android:grantUriPermissions': 'true',
        'android:permission': 'android.permission.MANAGE_DOCUMENTS',
      },
      'intent-filter': [{ action: [{ $: { 'android:name': 'android.content.action.DOCUMENTS_PROVIDER' } }] }],
    });
    return c;
  });
  return withDangerousMod(config, ['android', async c => {
    const destination = path.join(c.modRequest.platformProjectRoot, 'app/src/main/java/com/fengluo/live2dmodels');
    await fs.mkdir(destination, { recursive: true });
    for (const file of ['ModelsStorage.java', 'ModelsDocumentsProvider.java'])
      await fs.copyFile(path.join(c.modRequest.projectRoot, 'android-models', file), path.join(destination, file));
    return c;
  }]);
};
