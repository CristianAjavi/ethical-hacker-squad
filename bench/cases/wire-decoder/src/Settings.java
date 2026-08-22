package proto;

/** Limits the peer cannot change. Set once from configuration at start-up. */
public final class Settings {
    public static final int MAX_FRAME_BYTES = 131_072;
    public static final int MAX_STRING_BYTES = 65_535;

    private Settings() {
    }
}
