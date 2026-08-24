from flask_restful import Resource

from api import service
from api.permissions import AuthorityPermission, TagPermission


class AuthenticatedResource(Resource):
    """Every subclass requires a session. It does not imply any role."""

    method_decorators = [service.login_required]


class CertificatesList(AuthenticatedResource):
    def get(self):
        return service.list_for(service.current_user())

    def post(self, data=None):
        permission = AuthorityPermission(data["authority"].id, service.current_user().roles)
        if not permission.can():
            return dict(message="You are not authorized to use this authority"), 403
        return service.create(**data), 201


class CertificatesUpload(AuthenticatedResource):
    def post(self, data=None):
        return service.upload(**data), 201


class CertificateTags(AuthenticatedResource):
    def post(self, certificate_id, data=None):
        for tag in data["tags"]:
            permission = TagPermission(tag.id, service.current_user())
            if not permission.can():
                return dict(message="You are not authorized to use this tag"), 403
        return service.attach_tags(certificate_id, data["tags"])


class CertificatesStats(AuthenticatedResource):
    def get(self):
        return service.counts_by_month()

    def post(self, data=None):
        permission = AuthorityPermission(data["authority"].id, service.current_user().roles)
        if not permission.can():
            return dict(message="You are not authorized to use this authority"), 403
        return service.recompute(data["authority"])
