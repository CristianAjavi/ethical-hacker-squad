from sqlalchemy import event


class Certificate:
    def __init__(self, **kwargs):
        self.name = kwargs.get("name")
        self.body = kwargs.get("body")
        self.authority = kwargs.get("authority")
        self.owner = kwargs.get("owner")
        self.tags = kwargs.get("tags") or []
        self.supersedes = kwargs.get("supersedes") or []
        self.notify = True
        self.superseded = False


@event.listens_for(Certificate.supersedes, "append")
def on_supersedes_append(target, value, initiator):
    """Keep the superseded certificate quiet: its lifecycle is over."""
    value.notify = False
    value.superseded = True
