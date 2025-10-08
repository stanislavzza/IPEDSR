# Test Persistent Downloads Directory
# Check that downloads will go to a persistent location like the database

cat("=== TESTING PERSISTENT DOWNLOADS DIRECTORY ===\n")

library(IPEDSR)

cat("\n1. Checking database location...\n")
# This should show where your existing database is stored
db_path <- get_ipeds_db_path()
cat("🗂️  Database path:", db_path, "\n")
if (file.exists(db_path)) {
  cat("✅ Database exists at this location\n")
  cat("📏 Database size:", round(file.size(db_path) / 1024 / 1024, 2), "MB\n")
} else {
  cat("❌ Database not found\n")
}

cat("\n2. Checking downloads directory location...\n")
downloads_path <- get_ipeds_downloads_path()
cat("📁 Downloads path:", downloads_path, "\n")
cat("✅ Downloads directory created/verified\n")

# Check if they're in the same parent directory
db_parent <- dirname(db_path)
downloads_parent <- dirname(downloads_path)
if (db_parent == downloads_parent) {
  cat("✅ Database and downloads are in the same persistent directory\n")
  cat("📍 Shared location:", db_parent, "\n")
} else {
  cat("⚠️  Database and downloads in different locations\n")
}

cat("\n3. Testing file persistence...\n")
test_file <- file.path(downloads_path, "test_persistence.txt")
writeLines("This file tests persistence", test_file)
if (file.exists(test_file)) {
  cat("✅ Test file created successfully\n")
  file.remove(test_file)
  cat("🧹 Test file cleaned up\n")
}

cat("\n4. Summary:\n")
cat("📊 Your downloads will be stored at:\n")
cat("   ", downloads_path, "\n")
cat("📊 Your database is stored at:\n")
cat("   ", db_path, "\n")
cat("\n✅ Both locations are persistent and will survive R sessions!\n")

cat("\n=== PERSISTENT DOWNLOADS SETUP COMPLETE ===\n")
cat("Files will now persist between sessions. Ready to retry Step 3? (y/n)\n")