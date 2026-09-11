/// What is built and what is only modelled.
///
/// `stack` and `zip` exist in the contract and the database shape so adding them is a
/// UI job, not a migration. They are not shown anywhere until they are built -- App
/// Review 2.1 rejects a "coming soon" button, and so would a friend.
enum FeatureFlags {
    static let stackRooms = false
    static let zipPhotos = false
}
