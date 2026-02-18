# Victor's Challenge

## Architecture and data flow

```mermaid
flowchart TB
  subgraph http [HTTP Layer]
    AuthController[AuthController]
    ProjectsController[ProjectsController]
    TasksController[TasksController]
    CommentsController[CommentsController]
    NotificationsController[NotificationsController]
  end

  subgraph app [Application Layer]
    AuthService[Auth / Session logic]
    ProjectService[Project + Invite services]
    TaskService[Task CRUD + filter]
    CommentService[Comment CRUD]
    NotificationService[Notification read/mark]
  end

  subgraph domain [Domain Layer]
    User[User]
    Project[Project]
    Membership[Membership]
    Task[Task]
    Comment[Comment]
    Notification[Notification]
  end

  subgraph jobs [Background Jobs]
    CommentNotificationJob[CommentNotificationJob]
  end

  AuthController --> AuthService
  AuthService --> User
  ProjectsController --> ProjectService
  ProjectService --> Project
  ProjectService --> Membership
  TasksController --> TaskService
  TaskService --> Task
  CommentsController --> CommentService
  CommentService --> Comment
  CommentService --> CommentNotificationJob
  CommentNotificationJob --> Notification
  NotificationsController --> NotificationService
  NotificationService --> Notification
```

---

## Data model

| Model            | Key attributes                                                                                                    | Associations                                                                                                                                    |
| ---------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| **User**         | email, password_digest, name                                                                                      | has_many memberships; has_many projects through memberships; has_many assigned_tasks (Task assignee); has_many comments; has_many notifications |
| **Project**      | name, description, (optional) user_id for owner                                                                   | has_many memberships; has_many members through memberships; has_many tasks                                                                      |
| **Membership**   | user_id, project_id, role (e.g. owner, member)                                                                    | belongs_to user, project                                                                                                                        |
| **Task**         | project_id, assignee_id, title, description, status (todo/in_progress/done), priority (low/medium/high), due_date | belongs_to project, assignee (User); has_many comments                                                                                          |
| **Comment**      | task_id, user_id, content                                                                                         | belongs_to task, user                                                                                                                           |
| **Notification** | user_id, read (boolean), notifiable_type, notifiable_id or payload (JSON), message                                | belongs_to user                                                                                                                                 |

- **Authorization**: Project member required for project/tasks/comments read and for creating tasks/comments. Only **project owner** can invite. Task **assignee** (or project member, per story) can update status/assignee. Only **comment author** can edit/delete. Notifications scoped to `current_user`.

---

## Domain model sketch

High-level domain entities and relationships (reference for implementation and README):

```mermaid
erDiagram
  User ||--o{ Membership : has
  Project ||--o{ Membership : has
  Project ||--o{ Task : contains
  User ||--o{ Task : "assigned_to"
  Task ||--o{ Comment : has
  User ||--o{ Comment : writes
  User ||--o{ Notification : receives

  User {
    int id
    string email
    string name
    string password_digest
  }

  Project {
    int id
    string name
    string description
  }

  Membership {
    int id
    int user_id
    int project_id
    string role
  }

  Task {
    int id
    int project_id
    int assignee_id
    string title
    string description
    string status
    string priority
    date due_date
  }

  Comment {
    int id
    int task_id
    int user_id
    text content
  }

  Notification {
    int id
    int user_id
    boolean read
    string message_or_type
    json payload
  }
```

- **Aggregates**: Project (root: Project, with Memberships and Tasks); Task (with Comments); User (identity + Memberships, assigned Tasks, Notifications). Notifications are standalone, created by jobs.

---
