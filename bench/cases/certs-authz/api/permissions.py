"""Permission objects. Each one answers can() for the current principal."""


class AuthorityPermission:
    """May the caller issue against this authority?"""

    def __init__(self, authority_id, roles):
        self.authority_id = authority_id
        self.roles = roles

    def can(self):
        return any(r.authority_id == self.authority_id for r in self.roles)


class TagPermission:
    def __init__(self, tag_id, user):
        self.tag_id = tag_id
        self.user = user

    def can(self):
        return any(t.id == self.tag_id for t in self.user.tags)
