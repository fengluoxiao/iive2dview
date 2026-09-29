export type DirectoryEntry = { name: string; directory: boolean };
export type DirectoryModel = { id: string; character: string; outfit: string };

// Adapter keeps traversal testable without loading the React Native runtime.
export async function scanModelDirectory(list: (relative: string) => Promise<DirectoryEntry[]>) {
  const models: DirectoryModel[] = [];
  const errors: string[] = [];
  const pending = [''];
  while (pending.length) {
    const relative = pending.pop()!;
    try {
      for (const entry of await list(relative)) {
        if (entry.name.startsWith('.') || /[/\\\0]/.test(entry.name)) continue;
        const path = relative ? `${relative}/${entry.name}` : entry.name;
        if (entry.directory) {
          if (path.split('/').length < 64) pending.push(path);
          else errors.push(`${path}：目录层数超过 64`);
        } else if (entry.name.toLowerCase().endsWith('.model3.json')) {
          const outfit = entry.name.slice(0, -12);
          const parts = path.split('/');
          const wrapped = /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(parts[0]);
          const index = wrapped ? 1 : 0;
          models.push({ id: path, character: parts.length > index + 1 ? parts[index] : outfit, outfit });
        }
      }
    } catch (error) { errors.push(`${relative || 'models'}：${error instanceof Error ? error.message : String(error)}`); }
  }
  models.sort((a, b) => a.id.localeCompare(b.id));
  return { models, errors };
}
