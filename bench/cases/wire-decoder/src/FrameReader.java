package proto;

import java.io.DataInputStream;
import java.io.IOException;

/** Reads one frame off the socket and hands its body to the value decoder. */
public final class FrameReader {
    private final DataInputStream in;

    public FrameReader(DataInputStream in) {
        this.in = in;
    }

    public byte[] readFrame() throws IOException {
        int length = in.readInt();
        if (length < 0 || length > Settings.MAX_FRAME_BYTES) {
            throw new MalformedFrameException("frame length out of range: " + length);
        }
        byte[] body = new byte[length];
        in.readFully(body);
        return body;
    }

    public String readLabel() throws IOException {
        int length = in.readUnsignedShort();
        byte[] bytes = new byte[length];
        in.readFully(bytes);
        return new String(bytes, "utf-8");
    }
}
