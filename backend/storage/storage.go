package storage

import (
	"github.com/filebrowser/filebrowser/v2/backend/auth"
	"github.com/filebrowser/filebrowser/v2/backend/settings"
	"github.com/filebrowser/filebrowser/v2/backend/share"
	"github.com/filebrowser/filebrowser/v2/backend/users"
)

// Storage is a storage powered by a Backend which makes the necessary
// verifications when fetching and saving data to ensure consistency.
type Storage struct {
	Users    users.Store
	Share    *share.Storage
	Auth     *auth.Storage
	Settings *settings.Storage
}
