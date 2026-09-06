# IdentifyClassesNoChannelActiivity.ps1

## Purpose

`IdentifyClassesNoChannelActiivity.ps1` reports whether the General channel in selected class
Teams has meaningful root-post activity. It is a read-only diagnostic: it does not create, change,
or delete Teams, channels, messages, memberships, or assignments.

Administrators can provide Team IDs from a CSV, paste IDs into an input dialog, or discover SDS
class Teams created in an inclusive date range. The report distinguishes user posts, service posts
such as assignment notifications, and hidden Graph lifecycle events.

## Prerequisites

Install the Microsoft Graph PowerShell SDK. The date-search option also requires the Exchange
Online PowerShell module.

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

Connect to the intended tenant before running the script. It validates existing sessions and does
not sign in automatically.

```powershell
Connect-MgGraph -Scopes 'Channel.ReadBasic.All', 'ChannelMessage.Read.All', 'Group.Read.All', 'Team.ReadBasic.All'
```

When selecting SDS discovery by date, connect to Exchange Online too:

```powershell
Connect-ExchangeOnline
```

App-only authentication is supported when Entra ID grants and consents equivalent application
permissions. Delegated authentication can report only Teams where the signed-in account is a direct
member, and message access can still be denied for individual channels.

## Run

```powershell
.\IdentifyClassesNoChannelActiivity.ps1
```

Choose one input method when prompted:

| Choice | Input | Best use |
| --- | --- | --- |
| `1` | CSV file | Repeatable checks against a prior report or maintained Team-ID list. The script asks which GUID-bearing column to use. |
| `2` | Pasted IDs | A small, ad hoc set of Team IDs separated by commas or new lines. |
| `3` | SDS search by creation date | A date-bounded discovery of hidden-membership, Team-enabled SDS `Section` groups. |

Team IDs are validated, normalized, and de-duplicated before Graph checks begin.

## Activity Rules

The script queries the General channel’s root messages with `Get-MgTeamChannelMessage -All`.
`-All` follows Graph pagination, so the result includes all readable root posts in that channel.

| Message shape | Report treatment |
| --- | --- |
| Message with `From.User.Id` | User activity. |
| Non-user message that is not a lifecycle event | System/service activity. This includes assignment-service posts, whether or not they contain attachments. |
| `MessageType = systemEvent` | Excluded as a lifecycle event. |
| `MessageType = unknownFutureValue` with body `<systemEventMessage/>` | Excluded as a lifecycle event. Graph can use this SDK representation for hidden Team/channel events. |

The `EventDetail` property is not enough to classify a message as hidden: assignment posts can have
it. The script uses the message type and lifecycle body signature instead.

The script currently evaluates **root posts only**. Replies are not read or included in counts or
latest-activity fields. Treat `NoChannelActivity` as “no qualifying General-channel root posts,”
not as proof that the Team has had no activity elsewhere.

## Report Columns

The timestamped CSV is written to `%TEMP%\EDU Scripts\ClassChannelActivity\` by default.

| Column | Meaning |
| --- | --- |
| `DisplayName`, `TeamId`, `ChannelName`, `ChannelId` | Team and General-channel identity. |
| `LatestUserActivity` | Latest readable root post from a user. |
| `LatestSystemActivity` | Latest readable non-user, non-lifecycle root post. |
| `LatestChannelActivity` | Latest qualifying activity of either type. |
| `LatestActivityType` | `User` or `SystemOrService`, based on the latest qualifying post. |
| `UserActivityMessageCount`, `SystemActivityMessageCount` | Qualifying root-post counts by type. |
| `IgnoredSystemEventCount` | Lifecycle records excluded because they are not visible channel posts. |
| `Status` | `Active`, `NoChannelActivity`, `DelegatedUserNotMember`, `DelegatedAccessDenied`, or `Error`. |
| `ErrorStage`, `HttpStatus`, `RequestId`, `Error` | Graph troubleshooting details when a Team cannot be evaluated. |

## Configuration

| Setting | How to change it | Notes |
| --- | --- | --- |
| Output location | `-OutputDirectory 'C:\Reports\ClassChannelActivity'` | Creates the folder when needed. |
| Automatic CSV opening | `-SkipOpenResults` | Useful for scheduled or repeated attended runs. |
| Teams in scope | Choose CSV, pasted IDs, or date discovery | Date discovery has inclusive `yyyy-MM-dd` prompts and is the preferred way to keep the scope bounded. |
| Graph sign-in method | Establish delegated or app-only Graph session before running | The script does not call `Connect-MgGraph`; use the model suited to the required tenant scope. |

The SDS extension key and `Section` value used for date discovery are service-defined. Do not change
them casually. Altering the hidden-membership or Team-enabled candidate criteria changes discovery
results and should first be tested in a non-production tenant.

## Troubleshooting

- **`DelegatedUserNotMember`:** The delegated account is not a direct member of the Team. Use an
  appropriate account or app-only authentication with approved application permissions.
- **`DelegatedAccessDenied`:** The account is a Team member but cannot read that channel’s
  messages. Review membership and channel access.
- **`NoChannelActivity` with a nonzero `IgnoredSystemEventCount`:** Graph returned only hidden
  lifecycle events, not qualifying posts. This is expected for a newly created or otherwise empty
  Team.
- **Assignment appears as activity:** Assignment-service notifications are intentionally counted as
  `SystemOrService` activity, even when the message body has no attachment.
- **Missing expected reply activity:** Replies are outside the current report definition. Inspect
  the channel directly or extend the script with the Graph replies endpoint after validating the
  additional request volume and permissions.

## Safe Test Procedure

1. Confirm the target tenant and connect to Graph before starting.
2. Test one known empty class Team. It should show `NoChannelActivity`; lifecycle-only records are
   visible through `IgnoredSystemEventCount`.
3. Test one Team with a user post and one with an assignment notification. Confirm the expected
   `LatestActivityType` and counts.
4. Run a narrow SDS date search before using a broad range, then archive the timestamped CSV with
   the search date range used.
# IdentifyClassesNoChannelActiivity.ps1

## Purpose

`IdentifyClassesNoChannelActiivity.ps1` reports General-channel activity for class Teams supplied
from a CSV, an input dialog, or an SDS date-range search. The script uses existing Microsoft Graph
and, when date discovery is selected, Exchange Online sessions. It does not modify tenant data.

## Activity Classification

The report treats General-channel messages as activity, but excludes Microsoft Graph lifecycle
events that are not visible posts in Teams. The Graph PowerShell SDK can report them as
`systemEvent` or as `unknownFutureValue` with a `<systemEventMessage/>` body. An
`unknownFutureValue` message with `EventDetail` is not excluded solely for that reason: assignment
posts use that shape too. It records user and service activity separately:

- `LatestUserActivity` and `UserActivityMessageCount` identify messages with a user sender.
- `LatestSystemActivity` and `SystemActivityMessageCount` identify messages without a user sender,
  including posts made by the Assignments service.
- `LatestChannelActivity` is the most recent message of either type.
- `LatestActivityType` is `User` or `SystemOrService`, identifying the source of that most recent
  activity.
- `IgnoredSystemEventCount` identifies Graph lifecycle events excluded from activity.
- `Status` is `Active` when a user or service message was returned and `NoChannelActivity` when
  only event records, or no records, were returned.

The script currently evaluates General-channel root posts. Replies are not included in these
activity fields.

## Run

Connect to Microsoft Graph before running the script. When SDS discovery by date is selected,
connect to Exchange Online as well. The script verifies existing sessions and does not sign in
automatically.

```powershell
.\IdentifyClassesNoChannelActiivity.ps1
```

Use `-SkipOpenResults` to prevent the exported CSV from opening automatically:

```powershell
.\IdentifyClassesNoChannelActiivity.ps1 -SkipOpenResults
```

Reports are exported to `%TEMP%\ClassChannelActivity\` by default. Use `-OutputDirectory` to
select another output directory.