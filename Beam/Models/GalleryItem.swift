//
//  GalleryItem.swift
//  beam
//
//  Created by Robin Speijer on 16-07-15.
//  Copyright © 2015 Awkward. All rights reserved.
//

import UIKit
import Snoo
import CoreData
import AWKGallery
import SDWebImage

class GalleryItem: NSObject {
    
    var mediaObject: MediaObject?
    
    var size: CGSize? {
        get {
            if let width = self.mediaObject?.pixelWidth?.floatValue, let height = self.mediaObject?.pixelHeight?.floatValue {
                return CGSize(width: CGFloat(width), height: CGFloat(height))
            }
            return nil
        }
        set (newSize) {
            self.mediaObject?.managedObjectContext?.performAndWait {
                if let width = newSize?.width, let height = newSize?.height {
                    self.mediaObject?.pixelWidth = NSNumber(value: Float(width))
                    self.mediaObject?.pixelHeight = NSNumber(value: Float(height))
                }
            }
        }
    }
    
    var isAnimated: Bool {
        return mediaObject is MediaAnimatedGIF
    }
    
    var isNSFW: Bool {
        return mediaObject?.isNSFW ?? false
    }
    
    var animatedURL: URL? {
        guard let animatedGIF = mediaObject as? MediaAnimatedGIF else {
            return nil
        }
        return animatedGIF.videoURL
    }
    
    var isMP4GIF: Bool {
        guard let animatedGIF = mediaObject as? MediaAnimatedGIF else {
            return false
        }
        return animatedGIF.videoURL != nil
        //TODO: Check if the URL contains a mp4 extension or in case of Reddit links they will end with .gif, but contain "fm=mp4" (format is mp4) if the URL is a MP4 URL
//        return self.mediaObject?.galleryItem.animatedURLString?.pathExtension.contains("mp4") == true || self.mediaObject?.galleryItem.animatedURLString?.absoluteString.contains("fm=mp4") == true
    }
    
    fileprivate var cachedContentType: AWKGalleryItemContentType?
    
    init(mediaObject: MediaObject) {
        self.mediaObject = mediaObject
        super.init()
    }
    
}

// MARK: - AWKGalleryItem
extension GalleryItem: AWKGalleryItem {
    
    @objc var contentURL: URL? {
        if self.isAnimated {
            return self.animatedURL
        } else if let url = self.mediaObject?.contentURL {
            return url
        } else {
            NSLog("ContentURL missing")
            return nil
        }
    }
    
    @objc var contentType: AWKGalleryItemContentType {
        get {
            if let cachedContentType: AWKGalleryItemContentType = self.cachedContentType {
                return cachedContentType
            }
            guard self.isAnimated else {
                return .image
            }
            let pathExtension: String? = self.animatedURL?.pathExtension
            //The path extenion is gif or the cherry mistake: gif.png. This means it's a gif file
            let type: AWKGalleryItemContentType = pathExtension == "gif" || pathExtension == "gif.png" ? .animatedImage : .repeatingMovie
            cachedContentType = type
            return type
        }
        set {
            
        }
    }
    
    @objc var placeholderImage: UIImage? {
        if let urlString = self.mediaObject?.thumbnailWithSize(UIScreen.main.bounds.size)?.url?.absoluteString {
            return SDImageCache.shared().imageFromDiskCache(forKey: urlString)
        }
        return nil
    }
    
    @objc var contentData: Any? {
        get {
            if let url = self.contentURL {
                return SDImageCache.shared().imageFromDiskCache(forKey: url.absoluteString)
            }
            return nil
        } set {
            if let url = self.contentURL, let contentData = contentData as? UIImage {
                SDImageCache.shared().store(contentData, forKey: url.absoluteString)
            }
        }
    }
    
    @objc var contentSize: CGSize {
        return CGSize(width: CGFloat(self.mediaObject?.pixelWidth?.floatValue ?? 0), height: CGFloat(self.mediaObject?.pixelHeight?.floatValue ?? 0))
    }
    
    fileprivate var isAlbumItem: Bool {
        return (self.mediaObject?.content as? Post)?.mediaObjects?.count ?? 0 > 1
    }
    
    @objc var attributedTitle: NSAttributedString? {
        if let post = self.mediaObject?.content as? Post, let postTitle = post.title, !self.isAlbumItem {
            return NSAttributedString(string: postTitle.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), attributes: [NSAttributedStringKey.foregroundColor: UIColor.white, NSAttributedStringKey.font: UIFont.systemFont(ofSize: 17)])
        } else if let imageTitle = self.mediaObject?.captionTitle, self.isAlbumItem {
            let paragraphStyle = NSMutableParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
            paragraphStyle.paragraphSpacing = 4
            return NSAttributedString(string: imageTitle.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), attributes: [NSAttributedStringKey.foregroundColor: UIColor.white, NSAttributedStringKey.font: UIFont.systemFont(ofSize: 17), NSAttributedStringKey.paragraphStyle: paragraphStyle])
        }
        return nil
    }
    
    @objc var attributedSubtitle: NSAttributedString? {
        if self.mediaObject?.captionTitle != nil || self.mediaObject?.captionDescription != nil {
            let content = NSMutableAttributedString()
            
            // Show the caption title in the subtitle for posts, as the post title is being shown in the title instead of the caption title
            if !self.isAlbumItem {
                
                if let captionTitle = self.mediaObject?.captionTitle {
                    
                    let titleString = NSAttributedString(string: captionTitle.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), attributes: [NSAttributedStringKey.foregroundColor: UIColor.white, NSAttributedStringKey.font: UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: UIFontTextStyle.footnote).pointSize, weight: UIFont.Weight.medium)])
                    content.append(titleString)
                }
                
                if self.mediaObject?.captionTitle != nil && self.mediaObject?.captionDescription != nil {
                    content.append(NSAttributedString(string: "\n\n"))
                }
                
            }
            
            if let captionDescription = self.mediaObject?.captionDescription {
                
                let subtitleString = NSAttributedString(string: captionDescription, attributes: [NSAttributedStringKey.foregroundColor: UIColor.white.withAlphaComponent(0.8), NSAttributedStringKey.font: UIFont.preferredFont(forTextStyle: UIFontTextStyle.footnote)])
                content.append(subtitleString)
            }
            
            return content
        }
        
        return nil
    }
    
}

func == (lhs: GalleryItem, rhs: GalleryItem) -> Bool {
    return lhs.contentURL == rhs.contentURL
}

extension Snoo.MediaObject {
    
    var galleryItem: GalleryItem {
        get {
            return GalleryItem(mediaObject: self)
        }
        set {
            // Don't do anything. It's already saved.
        }
    }
    
}
