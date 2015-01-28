from django.conf.urls.defaults import *
from bookmarks.views import *

urlpatterns = patterns('', 
    (r'^users/([\w-]+)/$',              bookmark_list),
    (r'^users/([\w-]+)/tags/$',         tag_list),
    (r'^users/([\w-]+)/tags/([\w-]+)/', tag_detail),
    (r'^users/([\w-]+)/(.+)',           BookmarkDetail()),
)