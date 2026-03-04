pub mod guild;
pub mod hunter;
pub mod quest;
pub mod user;

pub mod prelude {
    pub use crate::guild::Entity as Guild;
    pub use crate::hunter::Entity as Hunter;
    pub use crate::quest::Entity as Quest;
    pub use crate::user::Entity as User;
}
