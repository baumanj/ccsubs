# Crisis Clinic subs/swap tool

This is a web application for facilitating exchanging shift assignments.

## TODO:
* Remind about upcoming shifts (esp holiday) if they were scheduled more than a week out
* Don't allow signing up for an on-call when one has already done one that month
* "Ccsubs issue" email about failure to create request with conflicting availability
* Smart exclusions for broadcast email and shift tracking
* On-call tracking
  * Need info about what a volunteer's default shift
* Render availability query page as calendar
* Put availabilities where Availability.match? is true at the top of the list
* Allow admins to look at user swap history
* Add gravatar to request detail
* Send staff email notifications about shift changes
* Alert staff and volunteer 48 hours in advance about shifts that look like they won't be covered and remind volunteer to call in the absence
* Fix implicitly created!
* Better handle availability/request conflicts
* Allow admins to look at all others availabilty for a given shift to help Travis
* Know when shifts are low (get shift information)
* Disallow doing two consecutive shifts
* (Admin) view historical requests
### Future
* Change Request model name to something less confusing with HTTP request (Ask? CoverageRequest?)
* Add poteintial matches to RequestsController#show for other users' requests
* Update user fixture to test vics with 4 digits
* Clean up mailers
* Metaprogramming around Request::MATCH_TYPE_MAP
* Allow admin to do all different actions as different users
* Make create request button from others request page jump past step 1 of request creation process
* Clean up partial usage, esp collections
* The phone and browser have inconsistent behavior, phone seems to require all fields to be filled each time, where browser lets you edit one field, and leave others untouched (observed mainly in the profile edit page).
* Mass emails for upcoming shifts that are understaffed
* alerts when 2+ request for shame shift
* record declines with reason
* See if I can replace User#upcoming_coverage with a proper relation
* Change "reset password" language
* Add some stats: (how many requests open, etc.)
* Add explicit check for potential matches
* From an admin view of a user, links to their requests and availability pages.
* Add stats on % of requests actually getting filled
