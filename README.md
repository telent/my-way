# My Way

Well, what else would you call a personal blogging engine based on
Sinatra?

pages/ # also partials
articles/
articles/drafts/

* write draft post
* change status to published
* some kind of navigationy sidebar thing to provide easy access to
 popular or timeless posts
* embed bits of code
* add pictures and stuff
* source formats including textile (for legacy content) and markdown
* use git for 

file format is markdown (=>kramdown) or html or textile (=>redcarpet)
selected by file extension 

First few lines are header lines a la mail headers.  

Subject:
Date:
From:


each post is a file which gets htmlified then top&tailed
