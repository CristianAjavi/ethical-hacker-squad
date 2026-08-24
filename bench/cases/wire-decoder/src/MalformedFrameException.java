package proto;

import java.io.IOException;

public class MalformedFrameException extends IOException {
    public MalformedFrameException(String message) {
        super(message);
    }
}
