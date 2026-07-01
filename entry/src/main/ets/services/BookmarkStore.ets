import { preferences } from '@kit.ArkData';
import { BookmarkItem } from '../model/BookmarkModel';
import { VideoDataType } from '../common/constants/CommonConstants';

const TAG = '[BookmarkStore]';
const STORE_NAME = 'video_bookmarks';
const KEY_BOOKMARKS = 'bookmark_list';

/**
 * Persistent bookmark storage backed by preferences.
 * All operations are synchronous on in-memory cache, async on disk.
 */
export class BookmarkStore {
  private static instance: BookmarkStore;
  private prefs: preferences.Preferences | null = null;
  private cache: BookmarkItem[] = [];

  static getInstance(): BookmarkStore {
    if (!BookmarkStore.instance) {
      BookmarkStore.instance = new BookmarkStore();
    }
    return BookmarkStore.instance;
  }

  /** Initialize the preferences store and load cached data. */
  async init(context: Context): Promise<void> {
    if (this.prefs) {
      return;
    }
    this.prefs = preferences.getPreferencesSync(context, { name: STORE_NAME });
    await this.prefs.flush();
    this.cache = await this.loadAll();
  }

  /** Load all bookmarks from disk. */
  private async loadAll(): Promise<BookmarkItem[]> {
    if (!this.prefs) return [];
    try {
      const raw = this.prefs.getSync(KEY_BOOKMARKS, '[]') as string;
      return JSON.parse(raw) as BookmarkItem[];
    } catch (e) {
      console.error(`${TAG} loadAll失败: ${JSON.stringify(e)}`);
      return [];
    }
  }

  /** Persist the in-memory cache to disk. */
  private async persist(): Promise<void> {
    if (!this.prefs) return;
    try {
      this.prefs.putSync(KEY_BOOKMARKS, JSON.stringify(this.cache));
      await this.prefs.flush();
    } catch (e) {
      console.error(`${TAG} persist失败: ${JSON.stringify(e)}`);
    }
  }

  /** Get all bookmarks (newest first). */
  getAll(): BookmarkItem[] {
    return [...this.cache].sort((a, b) => b.addedTime - a.addedTime);
  }

  /** Check if a URL is already bookmarked. */
  isBookmarked(url: string): boolean {
    return this.cache.some((item: BookmarkItem) => item.url === url);
  }

  /** Add a bookmark. Returns false if already exists. */
  async add(url: string, title: string, videoType: VideoDataType, thumbnailPath: string): Promise<boolean> {
    if (this.isBookmarked(url)) {
      return false;
    }
    const item: BookmarkItem = {
      url: url,
      title: title,
      videoType: videoType,
      thumbnailPath: thumbnailPath,
      addedTime: Date.now()
    };
    this.cache.push(item);
    await this.persist();
    return true;
  }

  /** Remove a bookmark by URL. */
  async remove(url: string): Promise<void> {
    const before = this.cache.length;
    this.cache = this.cache.filter((item: BookmarkItem) => item.url !== url);
    if (this.cache.length !== before) {
      await this.persist();
    }
  }

  /** Toggle bookmark: add if not exists, remove if exists. Returns new state. */
  async toggle(url: string, title: string, videoType: VideoDataType, thumbnailPath: string): Promise<boolean> {
    if (this.isBookmarked(url)) {
      await this.remove(url);
      return false;
    } else {
      await this.add(url, title, videoType, thumbnailPath);
      return true;
    }
  }
}
