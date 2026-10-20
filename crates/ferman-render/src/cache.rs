//! The bitmap caches of the render thread: tiles and thumbnails, each capped by bytes and evicted
//! least recently used first (docs/ARCHITECTURE.md §4.7).
//!
//! A key holds the page's render key, so a new revision of a page makes its old bitmaps
//! unreachable; they age out. Closing a document drops its entries at once.

use std::hash::Hash;

use lru::LruCache;

use crate::thread::DocumentId;
use crate::tiles::{Item, PixelRect};

/// What a cached bitmap is for: one item of one page at one render key.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub(crate) struct BitmapKey {
    pub(crate) document: DocumentId,
    pub(crate) render_key: u64,
    pub(crate) item: Item,
}

/// A rendered bitmap as the cache keeps it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct Bitmap {
    pub(crate) rect: PixelRect,
    pub(crate) pixels: Vec<u8>,
}

/// An LRU cache of bitmaps that holds at most `cap` bytes of pixels.
#[derive(Debug)]
pub(crate) struct BitmapCache<K: Hash + Eq = BitmapKey> {
    entries: LruCache<K, Bitmap>,
    bytes: usize,
    cap: usize,
}

impl<K: Hash + Eq + Copy> BitmapCache<K> {
    /// An empty cache of at most `cap` bytes; a cap of 0 keeps nothing.
    pub(crate) fn new(cap: usize) -> Self {
        Self {
            entries: LruCache::unbounded(),
            bytes: 0,
            cap,
        }
    }

    /// The bitmap for `key`, now the most recently used.
    pub(crate) fn get(&mut self, key: &K) -> Option<&Bitmap> {
        self.entries.get(key)
    }

    /// Keeps `bitmap` for `key`, evicting the least recently used entries until it fits. A bitmap
    /// larger than the whole cache is not kept.
    pub(crate) fn insert(&mut self, key: K, bitmap: Bitmap) {
        let size = bitmap.pixels.len();
        if size > self.cap {
            self.remove(&key);
            return;
        }
        self.remove(&key);
        while self.bytes.saturating_add(size) > self.cap {
            match self.entries.pop_lru() {
                Some((_, evicted)) => self.bytes = self.bytes.saturating_sub(evicted.pixels.len()),
                None => break,
            }
        }
        self.bytes = self.bytes.saturating_add(size);
        self.entries.put(key, bitmap);
    }

    /// Drops the entry for `key`, if any.
    fn remove(&mut self, key: &K) {
        if let Some(old) = self.entries.pop(key) {
            self.bytes = self.bytes.saturating_sub(old.pixels.len());
        }
    }

    /// Keeps only the entries `keep` selects.
    pub(crate) fn retain(&mut self, mut keep: impl FnMut(&K) -> bool) {
        let gone: Vec<K> = self
            .entries
            .iter()
            .map(|(key, _)| *key)
            .filter(|key| !keep(key))
            .collect();
        for key in gone {
            self.remove(&key);
        }
    }

    /// The bytes of pixels held.
    #[cfg(test)]
    pub(crate) fn bytes(&self) -> usize {
        self.bytes
    }

    /// The number of bitmaps held.
    #[cfg(test)]
    pub(crate) fn len(&self) -> usize {
        self.entries.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn bitmap(size: usize, byte: u8) -> Bitmap {
        Bitmap {
            rect: PixelRect {
                x: 0,
                y: 0,
                width: 1,
                height: 1,
            },
            pixels: vec![byte; size],
        }
    }

    #[test]
    fn the_least_recently_used_goes_first() {
        let mut cache = BitmapCache::<u32>::new(300);
        cache.insert(1, bitmap(100, 1));
        cache.insert(2, bitmap(100, 2));
        cache.insert(3, bitmap(100, 3));
        // Using 1 makes 2 the oldest.
        assert!(cache.get(&1).is_some());
        cache.insert(4, bitmap(100, 4));
        assert!(cache.get(&2).is_none());
        assert!(cache.get(&1).is_some());
        assert!(cache.get(&3).is_some());
        assert!(cache.get(&4).is_some());
        assert_eq!(cache.bytes(), 300);
    }

    #[test]
    fn a_bitmap_larger_than_the_cache_is_not_kept() {
        let mut cache = BitmapCache::<u32>::new(100);
        cache.insert(1, bitmap(50, 1));
        cache.insert(2, bitmap(101, 2));
        assert!(cache.get(&2).is_none());
        assert!(cache.get(&1).is_some());
        assert_eq!(cache.bytes(), 50);
        let mut none = BitmapCache::<u32>::new(0);
        none.insert(1, bitmap(1, 1));
        assert_eq!(none.len(), 0);
    }

    #[test]
    fn replacing_an_entry_counts_it_once() {
        let mut cache = BitmapCache::<u32>::new(1000);
        cache.insert(1, bitmap(100, 1));
        cache.insert(1, bitmap(200, 2));
        assert_eq!(cache.bytes(), 200);
        assert_eq!(cache.get(&1).map(|b| b.pixels[0]), Some(2));
    }

    #[test]
    fn retain_drops_what_it_does_not_keep() {
        let mut cache = BitmapCache::<u32>::new(1000);
        for key in 0..6 {
            cache.insert(key, bitmap(10, 0));
        }
        cache.retain(|key| key % 2 == 0);
        assert_eq!(cache.len(), 3);
        assert_eq!(cache.bytes(), 30);
        assert!(cache.get(&1).is_none());
        assert!(cache.get(&2).is_some());
    }
}
