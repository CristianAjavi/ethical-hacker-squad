package proto;

import java.io.DataInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Decodes the typed values that make up a frame body. */
public final class ValueDecoder {
    private final DataInputStream in;

    public ValueDecoder(DataInputStream in) {
        this.in = in;
    }

    public byte[] readBlob() throws IOException {
        long declared = in.readInt() & 0xFFFFFFFFL;
        if (declared >= Integer.MAX_VALUE) {
            throw new MalformedFrameException("blob too large");
        }
        byte[] blob = new byte[(int) declared];
        in.readFully(blob);
        return blob;
    }

    public String readText() throws IOException {
        int declared = in.readUnsignedShort();
        if (declared > Settings.MAX_STRING_BYTES) {
            throw new MalformedFrameException("text too large");
        }
        byte[] bytes = new byte[declared];
        in.readFully(bytes);
        return new String(bytes, "utf-8");
    }

    public Map<String, Object> readMap() throws IOException {
        Map<String, Object> out = new HashMap<>();
        int entries = in.readUnsignedShort();
        for (int i = 0; i < entries; i++) {
            out.put(readText(), readValue());
        }
        return out;
    }

    public List<Object> readList() throws IOException {
        List<Object> out = new ArrayList<>();
        int entries = in.readUnsignedShort();
        for (int i = 0; i < entries; i++) {
            out.add(readValue());
        }
        return out;
    }

    public Object readValue() throws IOException {
        int tag = in.readUnsignedByte();
        switch (tag) {
            case 'S': return readText();
            case 'x': return readBlob();
            case 'M': return readMap();
            case 'A': return readList();
            case 'i': return in.readInt();
            default: throw new MalformedFrameException("unknown tag " + tag);
        }
    }
}
