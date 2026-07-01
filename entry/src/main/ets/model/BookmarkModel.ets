import { VideoDataType } from '../common/constants/CommonConstants';

/**
 * Represents a bookmarked video for quick replay.
 */
export interface BookmarkItem {
  /** Unique identifier (url acts as natural key) */
  url: string;
  /** Display title */
  title: string;
  /** Video source type */
  videoType: VideoDataType;
  /** Local thumbnail path (first-frame capture or placeholder) */
  thumbnailPath: string;
  /** Timestamp when bookmarked (ms since epoch) */
  addedTime: number;
}
