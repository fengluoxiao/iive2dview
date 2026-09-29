import com.fengluo.live2dmodels.ModelsStorage;
import java.io.File;
import java.io.FileNotFoundException;
import java.nio.file.Files;

public class ModelsStorageTest {
    interface Attempt { void run() throws Exception; }
    static void rejected(Attempt attempt) throws Exception {
        try { attempt.run(); throw new AssertionError("Unsafe path was accepted"); }
        catch (FileNotFoundException expected) { }
    }
    public static void main(String[] args) throws Exception {
        File temp = Files.createTempDirectory("live2d-models-test-").toFile();
        ModelsStorage storage = new ModelsStorage(temp);
        File folder = storage.child("models", "角色 #1");
        if (!folder.mkdir()) throw new AssertionError("mkdir");
        File model = storage.child(storage.id(folder), "test.model3.json");
        if (!model.createNewFile()) throw new AssertionError("create");
        if (!storage.resolve(storage.id(model)).equals(model)) throw new AssertionError("round trip");
        rejected(() -> storage.resolve("models/../models/角色 #1"));
        rejected(() -> storage.resolve("private"));
        rejected(() -> storage.child("models", "../outside"));
        rejected(() -> storage.child("models", "角色 #1"));
        rejected(() -> storage.id(temp));
        rejected(() -> storage.delete("models"));
        if (!System.getProperty("os.name").startsWith("Windows")) {
            File link = new File(storage.resolve("models"), "outside");
            Files.createSymbolicLink(link.toPath(), temp.toPath());
            rejected(() -> storage.resolve("models/outside"));
            Files.delete(link.toPath());
        }
        storage.delete(storage.id(folder));
        if (folder.exists()) throw new AssertionError("delete tree");
        Files.delete(storage.resolve("models").toPath()); Files.delete(temp.toPath());
        System.out.println("PASS: models creation, Unicode, path boundaries, duplicate protection and delete");
    }
}
