# Crisis Clinic subs/swap tool

This is a web application for facilitating exchanging shift assignments.

## TODO:
### Next steps
* Update help
* Allow admins to look at user swap history
* All hands on deck email
* Use CSV to change active users (upload full list rather than just new)
* Add gravatar to request detail
* Send staff email notifications about shift changes
* Alert staff and volunteer 48 hours in advance about shifts that look like they won't be covered and remind volunteer to call in the absence
* Fix implicitly created!
* Better handle availability/request conflicts
* Speed up availability pages (https://github.com/bbatsov/rails-style-guide#find-each)
* Allow admins to look at all others availabilty for a given shift to help Travis
* Notification to volunteer services for sub/swap requests that haven't been fulfilled when the shift is only one or two days away.
* Know when shifts are low (get shift information)
* Disallow doing two consecutive shifts
* Make it clear who is logged in (gravitar)
* auto log out at end of shift if on crisis line computer
* Daily pending request nag
* (Admin) view historical requests
### Future
* Change Request model name to something less confusing with HTTP request (Ask? CoverageRequest?)
* Add poteintial matches to RequestsController#show for other users' requests
* Don't use Time.now (https://github.com/bbatsov/rails-style-guide#time-now)
* Update user fixture to test vics with 4 digits
* Updrade to ruby 2.1
* Clean up mailers
* Metaprogramming around Request::MATCH_TYPE_MAP
* Allow admin to do all different actions as different users
* Make create request button from others request page jump past step 1 of request creation process
* Clean up partial usage, esp collections
* The phone and browser have inconsistent behavior, phone seems to require all fields to be filled each time, where browser lets you edit one field, and leave others untouched (observed mainly in the profile edit page).
* There seems to be a pretty fast timeout on the site (I typically was re-logging every couple of minutes).  Not sure if this is the site itself, or if it only allows one instance of me, and I was logging in from different browsers/devices, which signed me out of my previous instance.
* Don't allow requests to be edited into the past.
* Don't show past requests by default.
* Disable "Edit"/"Delete" buttons for past requests.
* If, upon request creation, there's a good match, go straight there rather than availability add.
* Calendar output (iCal, Google Calendar, etc.) to remind people of their swap obligations
* Mass emails for upcoming shifts that are understaffed
* alerts when 2+ request for shame shift
* record declines with reason
* See if I can replace User#upcoming_coverage with a proper relation
* Change "reset password" language
* Add some stats: (how many requests open, etc.)
* Add explicit check for potential matches
* Mobile optimized layout
* From an admin view of a user, links to their requests and availability pages.
* Automatically decline a request when the date of the earlier shift has passed; only consider a request pending when both shifts are in the future.
* Add tracking of when an swap offer was made. Nag the recipient if they don't respond in a couple days.
* Add an error for entering redundant availability
* Enter multiple availabilities faster
* Remove availability upon offer decline (and notify user)
* Make it clearer how to see who's available to swap with you (docs); improve workflow
* Add stats on % of requests actually getting filled

## Done
* Put suggested availabilities on the request creation page!
* Remove superfluous "details box" on request view
* Suggest adding availabilities corresponding to outstanding requests
* Notify when other users add availabilities matching your requests
* Add volunteerservices@crisisclinic.org to the CC on emails that confirm changes to the volunteer calendar.
* Update the language for accepting subs to remind volunteers that the accepted shift is now their responsibility and if they can't do it themselves, they need to find someone else to cover. Also know as "no backsies".
* Make sure notification emails are being sent as intended and clearly document when emails should be sent and to whom.
* Create a view for the list of upcoming confirmed subs and swaps.
* Improve user's view of their own requests (see past, fulfilled, etc)
* Add a feature to create new volunteer accounts by uploading a CSV file.
* Be consisent: "create a request" vs "new request"
* Be clear about whether a request is sub-only or willing to swap
* Go to "add availability" after creating request if not sub-only
* Two sections: open and pending sub/swap requests
* Make accept/decline more prominent
* Send both people emails on request acceptance
