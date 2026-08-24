from marshmallow import fields, post_load

from api import models, service


class CertificateInputSchema:
    name = fields.String(required=True)
    body = fields.String(required=True)
    authority = fields.Nested("AuthoritySchema")
    supersedes = fields.List(fields.Integer())
    tags = fields.List(fields.Integer())

    @post_load
    def resolve(self, data, **kwargs):
        data["supersedes"] = [service.get_certificate(i) for i in data.get("supersedes", [])]
        data["tags"] = [t for t in service.current_user().tags
                        if t.id in set(data.get("tags", []))]
        return data


class CertificateOutputSchema:
    name = fields.String()
    owner = fields.String()
    superseded = fields.Boolean()
