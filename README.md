# Crisis Clinic subs/swap tool

This is a web application for facilitating exchanging shift assignments.

TODO:
* The phone and browser have inconsistent behavior, phone seems to require all fields to be filled each time, where browser lets you edit one field, and leave others untouched (observed mainly in the profile edit page).
* There seems to be a pretty fast timeout on the site (I typically was re-logging every couple of minutes).  Not sure if this is the site itself, or if it only allows one instance of me, and I was logging in from different browsers/devices, which signed me out of my previous instance.
* Don't allow requests to be edited into the past.
* Don't show past requests by default.
* Disable "Edit"/"Delete" buttons for past requests.

Tryna's feedback:
☑︎ Be consisent: "create a request" vs "new request"
☑︎ Be clear about whether a request is sub-only or willing to swap
☑︎ Go to "add availability" after creating request if not sub-only
☑︎ Two sections: open and pending sub/swap requests
☑︎ Make accept/decline more prominent
☑︎ Send both people emails on request acceptance