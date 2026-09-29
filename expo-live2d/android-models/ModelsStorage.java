package com.fengluo.live2dmodels;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

/** Only models is exposed, never the app's other private files. */
public final class ModelsStorage {
    private final File root;
    public ModelsStorage(File filesDirectory) throws IOException {
        root = new File(filesDirectory, "models").getCanonicalFile();
        if (!root.isDirectory() && !root.mkdirs()) throw new IOException("Cannot create models directory");
    }
    public File resolve(String id) throws FileNotFoundException {
        if (!id.equals("models") && !id.startsWith("models/")) throw new FileNotFoundException("Unknown document");
        File file = id.equals("models") ? root : new File(root, id.substring(7));
        try {
            File canonical = file.getCanonicalFile();
            if (!canonical.equals(root) && !canonical.getPath().startsWith(root.getPath() + File.separator))
                throw new FileNotFoundException("Outside models directory");
            // Do not follow symlinks or accept alternate path spellings.
            if (!file.getAbsolutePath().equals(canonical.getPath())) throw new FileNotFoundException("Invalid document path");
            if (!canonical.exists()) throw new FileNotFoundException("Document no longer exists");
            return canonical;
        } catch (IOException e) { throw new FileNotFoundException(e.getMessage()); }
    }
    public String id(File file) throws FileNotFoundException {
        String path = file.getAbsolutePath();
        if (!path.equals(root.getPath()) && !path.startsWith(root.getPath() + File.separator))
            throw new FileNotFoundException("Outside models directory");
        String id = path.equals(root.getPath()) ? "models" : "models/" + path.substring(root.getPath().length() + 1);
        if (!resolve(id).equals(file)) throw new FileNotFoundException("Invalid document");
        return id;
    }
    public File child(String parentId, String name) throws FileNotFoundException {
        if (name == null || name.isEmpty() || name.equals(".") || name.equals("..") || name.contains("/") || name.contains("\\") || name.indexOf('\0') >= 0)
            throw new FileNotFoundException("Invalid file name");
        File parent = resolve(parentId);
        if (!parent.isDirectory()) throw new FileNotFoundException("Parent is not a directory");
        File child = new File(parent, name);
        if (child.exists()) throw new FileNotFoundException("A file with this name already exists");
        return child;
    }
    public void delete(String id) throws FileNotFoundException {
        if (id.equals("models")) throw new FileNotFoundException("Cannot delete models root");
        File file = resolve(id);
        if (file.isDirectory()) {
            File[] children = file.listFiles();
            if (children == null) throw new FileNotFoundException("Cannot list directory");
            for (File child : children) delete(id(child));
        }
        if (!file.delete()) throw new FileNotFoundException("Cannot delete document");
    }
}
