import datetime
from django.db import models
from django.contrib.auth.models import User

class Tag(models.Model):
    name = models.SlugField(maxlength=100)

class Bookmark(models.Model):
    user                = models.ForeignKey(User)
    url                 = models.URLField(db_index=True)
    short_description   = models.CharField(maxlength=255)
    long_description    = models.TextField(blank=True)
    timestamp           = models.DateTimeField(default=datetime.datetime.now)
    public              = models.BooleanField()
    tags                = models.ManyToManyField(Tag)