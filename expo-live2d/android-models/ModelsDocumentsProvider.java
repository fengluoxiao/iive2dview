package com.fengluo.live2dmodels;

import android.database.Cursor;
import android.database.MatrixCursor;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;
import android.provider.DocumentsContract;
import android.provider.DocumentsContract.Document;
import android.provider.DocumentsContract.Root;
import android.provider.DocumentsProvider;
import android.webkit.MimeTypeMap;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.Locale;

public final class ModelsDocumentsProvider extends DocumentsProvider {
    private ModelsStorage storage;
    private static final String[] ROOT_COLUMNS = {Root.COLUMN_ROOT_ID, Root.COLUMN_DOCUMENT_ID,
        Root.COLUMN_TITLE, Root.COLUMN_SUMMARY, Root.COLUMN_FLAGS, Root.COLUMN_MIME_TYPES, Root.COLUMN_AVAILABLE_BYTES};
    private static final String[] DOCUMENT_COLUMNS = {Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME,
        Document.COLUMN_MIME_TYPE, Document.COLUMN_FLAGS, Document.COLUMN_SIZE, Document.COLUMN_LAST_MODIFIED};

    @Override public boolean onCreate() {
        try { storage = new ModelsStorage(getContext().getFilesDir()); return true; }
        catch (IOException e) { return false; }
    }
    @Override public Cursor queryRoots(String[] projection) throws FileNotFoundException {
        MatrixCursor cursor = new MatrixCursor(projection == null ? ROOT_COLUMNS : projection);
        cursor.newRow().add(Root.COLUMN_ROOT_ID, "models").add(Root.COLUMN_DOCUMENT_ID, "models")
            .add(Root.COLUMN_TITLE, "Live2D 模型") .add(Root.COLUMN_SUMMARY, "models")
            .add(Root.COLUMN_FLAGS, Root.FLAG_SUPPORTS_CREATE | Root.FLAG_SUPPORTS_IS_CHILD | Root.FLAG_LOCAL_ONLY)
            .add(Root.COLUMN_MIME_TYPES, "*/*").add(Root.COLUMN_AVAILABLE_BYTES, storage.resolve("models").getFreeSpace());
        return cursor;
    }
    private String mime(File file) {
        if (file.isDirectory()) return Document.MIME_TYPE_DIR;
        String name = file.getName(); int dot = name.lastIndexOf('.');
        String type = dot < 0 ? null : MimeTypeMap.getSingleton().getMimeTypeFromExtension(name.substring(dot+1).toLowerCase(Locale.ROOT));
        return type == null ? "application/octet-stream" : type;
    }
    private void row(MatrixCursor cursor, File file) throws FileNotFoundException {
        String id = storage.id(file);
        int flags = file.isDirectory() ? Document.FLAG_DIR_SUPPORTS_CREATE : Document.FLAG_SUPPORTS_WRITE;
        if (!id.equals("models")) flags |= Document.FLAG_SUPPORTS_DELETE | Document.FLAG_SUPPORTS_RENAME;
        cursor.newRow().add(Document.COLUMN_DOCUMENT_ID, id).add(Document.COLUMN_DISPLAY_NAME, file.getName())
            .add(Document.COLUMN_MIME_TYPE, mime(file)).add(Document.COLUMN_FLAGS, flags)
            .add(Document.COLUMN_SIZE, file.isDirectory() ? null : file.length()).add(Document.COLUMN_LAST_MODIFIED, file.lastModified());
    }
    @Override public Cursor queryDocument(String id, String[] projection) throws FileNotFoundException {
        MatrixCursor cursor = new MatrixCursor(projection == null ? DOCUMENT_COLUMNS : projection);
        row(cursor, storage.resolve(id)); return cursor;
    }
    @Override public Cursor queryChildDocuments(String parentId, String[] projection, String sortOrder) throws FileNotFoundException {
        MatrixCursor cursor = new MatrixCursor(projection == null ? DOCUMENT_COLUMNS : projection);
        File[] files = storage.resolve(parentId).listFiles();
        if (files == null) throw new FileNotFoundException("Cannot read directory");
        for (File file : files) {
            try { row(cursor, file); } catch (FileNotFoundException ignored) { /* Hide external symlinks. */ }
        }
        cursor.setNotificationUri(getContext().getContentResolver(), DocumentsContract.buildChildDocumentsUri(authority(), parentId));
        return cursor;
    }
    @Override public ParcelFileDescriptor openDocument(String id, String mode, CancellationSignal signal) throws FileNotFoundException {
        if (signal != null) signal.throwIfCanceled();
        File file = storage.resolve(id);
        if (file.isDirectory()) throw new FileNotFoundException("Not a file");
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.parseMode(mode));
    }
    @Override public String createDocument(String parentId, String mimeType, String name) throws FileNotFoundException {
        File file = storage.child(parentId, name);
        try {
            boolean created = Document.MIME_TYPE_DIR.equals(mimeType) ? file.mkdir() : file.createNewFile();
            if (!created) throw new IOException("Cannot create document");
            changed(parentId); return storage.id(file);
        } catch (IOException e) { throw new FileNotFoundException(e.getMessage()); }
    }
    @Override public void deleteDocument(String id) throws FileNotFoundException {
        String parent = storage.id(storage.resolve(id).getParentFile());
        storage.delete(id); changed(parent);
    }
    @Override public String renameDocument(String id, String name) throws FileNotFoundException {
        if (id.equals("models")) throw new FileNotFoundException("Cannot rename models root");
        File file = storage.resolve(id); String parent = storage.id(file.getParentFile());
        File target = storage.child(parent, name);
        if (!file.renameTo(target)) throw new FileNotFoundException("Cannot rename document");
        changed(parent); return storage.id(target);
    }
    @Override public boolean isChildDocument(String parentId, String id) {
        try { return storage.resolve(id).getPath().startsWith(storage.resolve(parentId).getPath() + File.separator); }
        catch (FileNotFoundException e) { return false; }
    }
    private String authority() { return getContext().getPackageName() + ".models.documents"; }
    private void changed(String parent) {
        getContext().getContentResolver().notifyChange(DocumentsContract.buildChildDocumentsUri(authority(), parent), null);
    }
}
