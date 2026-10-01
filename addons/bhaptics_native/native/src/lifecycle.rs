//! Bounded shutdown: release motors, request disconnect, then confirm adapter state.
use std::time::Duration;

pub(crate) trait Link {
    async fn zero(&self) -> Result<(), String>;
    async fn disconnect(&self) -> Result<(), String>;
    async fn connected(&self) -> Result<bool, String>;
}

pub(crate) async fn close(link: &impl Link) -> Result<Option<String>, String> {
    // A failed zero write must never prevent releasing the Bluetooth connection.
    let zero_error = tokio::time::timeout(Duration::from_millis(1500), link.zero())
        .await.map_err(|_| "Motor release timed out".to_string()).and_then(|v| v).err();
    verify_disconnect(link, Duration::from_secs(3)).await?;
    Ok(zero_error)
}

async fn verify_disconnect(link: &impl Link, budget: Duration) -> Result<(), String> {
    tokio::time::timeout(budget, async {
        loop {
            // Retry even if the previous request failed: BlueZ may still be completing it.
            let _ = tokio::time::timeout(Duration::from_millis(750), link.disconnect()).await;
            for _ in 0..5 {
                if matches!(link.connected().await, Ok(false)) { return; }
                tokio::time::sleep(Duration::from_millis(50)).await;
            }
        }
    }).await.map_err(|_| "Bluetooth disconnect was not confirmed within 3 seconds".into())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::{Cell, RefCell};
    struct Fake { calls: RefCell<Vec<&'static str>>, polls: Cell<usize>, release_error: bool, stuck: bool }
    impl Link for Fake {
        async fn zero(&self) -> Result<(), String> {
            self.calls.borrow_mut().push("zero");
            if self.release_error { Err("write failed".into()) } else { Ok(()) }
        }
        async fn disconnect(&self) -> Result<(), String> {
            self.calls.borrow_mut().push("disconnect"); Ok(())
        }
        async fn connected(&self) -> Result<bool, String> {
            self.calls.borrow_mut().push("check");
            self.polls.set(self.polls.get()+1); Ok(self.stuck || self.polls.get()<2)
        }
    }
    fn runtime() -> tokio::runtime::Runtime { tokio::runtime::Builder::new_current_thread().enable_all().build().unwrap() }
    #[test]
    fn waits_for_adapter_after_zero_even_when_zero_fails() {
        for release_error in [false,true] {
            let link=Fake { calls:RefCell::new(vec![]), polls:Cell::new(0), release_error, stuck:false };
            let result=runtime().block_on(close(&link)).unwrap();
            assert_eq!(result.is_some(),release_error);
            assert_eq!(&*link.calls.borrow(), &["zero","disconnect","check","check"]);
        }
    }
    #[test]
    fn stuck_adapter_is_an_error_not_a_clean_disconnect() {
        let link=Fake { calls:RefCell::new(vec![]), polls:Cell::new(0), release_error:false, stuck:true };
        assert!(runtime().block_on(verify_disconnect(&link,Duration::from_millis(10))).is_err());
    }
}
