pub mod chat_message;
pub mod friend_link;
pub mod friend_request;
pub mod guild;
pub mod guild_invite;
pub mod guild_item;
pub mod hunter;
pub mod hunter_inventory;
pub mod hunter_reward_ledger;
pub mod quest;
pub mod user;

pub mod prelude {
    pub use crate::chat_message::Entity as ChatMessage;
    pub use crate::friend_link::Entity as FriendLink;
    pub use crate::friend_request::Entity as FriendRequest;
    pub use crate::guild::Entity as Guild;
    pub use crate::guild_invite::Entity as GuildInvite;
    pub use crate::guild_item::Entity as GuildItem;
    pub use crate::hunter::Entity as Hunter;
    pub use crate::hunter_inventory::Entity as HunterInventory;
    pub use crate::hunter_reward_ledger::Entity as HunterRewardLedger;
    pub use crate::quest::Entity as Quest;
    pub use crate::user::Entity as User;
}
