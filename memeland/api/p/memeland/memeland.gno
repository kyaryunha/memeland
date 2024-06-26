package memeland

import (
	"std"
	"strconv"
	"strings"
	"time"
	"sort"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/seqid"
)

type Post struct {
	ID            string
	Data          string
	Author        std.Address
	Timestamp     time.Time
	UpvoteTracker *avl.Tree // address > struct{}{}
}

type Memeland struct {
	Posts       []*Post
	MemeCounter seqid.ID
}

// NewMemeland returns a pointer to a new Memeland object
// Initializes all the subfields
func NewMemeland() *Memeland {
	return &Memeland {
		Posts: make([]*Post, 0),
		MemeCounter: 0,
	}
}


// PostMeme - Adds a new post at timestamp, with data
// Panics in case data is empty or timestamp is invalid
// Returns the ID of the created Post
func (m *Memeland) PostMeme(data string, timestamp int64) string {
	var id = m.MemeCounter.Next().String()
	// var treeAddress = &avl.NewTree()
	var newPost = &Post{
		ID: id,
		Data: data,
		Author: std.PrevRealm().Addr(),
		Timestamp: time.Unix(timestamp, 0),
		UpvoteTracker: avl.NewTree(),
	}
	m.Posts = append(m.Posts, newPost);
	return newPost.ID
}

// Upvote increases the upvote count of a specific Post
// Panics if specified ID doesn't exist, or the user has already upvoted
func (m *Memeland) Upvote(id string) string {
	caller := std.PrevRealm().Addr().String()
	for i, post := range m.Posts {
		if post.ID == id {
			if post.UpvoteTracker.Has(caller) {
				panic("User has already upvoted.")
			} else {
				post.UpvoteTracker.Set(caller, true)
			}
		}
	}
	panic("ID doesn't exist.")

}

// GetPostsInRange returns a JSON object containing marshalled Posts in a specific timestamp range
// Timestamps are given as Unix seconds
// Supports pagination
// sortBy can be "UPVOTES" (most upvotes-first), or "DATE_CREATED" (newest-first)
// Panics if page < 1, pageSize < 1, or pageSize > 10
// Returns empty JSON object if there are no posts in the specified range.

type SortUpvotes []Post 
type SortDate []Post

func (s SortUpvotes) Len() int {
	return len(s)
}
func (s SortUpvotes) Swap(i, j int) {
	s[i], s[j] = s[j], s[i]
}
func (s SortUpvotes) Less(i, j int) bool {
	return s[i].UpvoteTracker.Size() > s[j].UpvoteTracker.Size()
}

func (s SortDate) Len() int {
	return len(s)
}
func (s SortDate) Swap(i, j int) {
	s[i], s[j] = s[j], s[i]
} 
func (s SortDate) Less(i, j int) bool {
	return s[i].Timestamp > s[j].Timestamp
}

func (m *Memeland) GetPostsInRange(startTimestamp, endTimestamp int64, page, pageSize int, sortBy string) string {
	var postLen = len(m.Posts)

	if sortBy == "UPVOTES" {
		sort.Sort(SortUpvotes(m.Posts))
	} else if sortBy == "DATE_CREATED" {
		sort.Sort(SortDate(m.Posts))
	}

	var resultPosts = make([]*Post, 0)




	for i, post := range m.Posts {
		if (int(i / pageSize) == (int(page) - 1)) {
			resultPosts = append(resultPosts, &post)
		}
	}

	return PostsToJSONString(resultPosts)
}


// getPost gets a post by ID
func (m *Memeland) getPost(id string) *Post {
	for i, post := range(m.Posts) {
		if post.ID == id {
			return post
		}
	}
	panic("post doesn't exist ")
}

// PostsToJSONString converts a slice of Post structs into a JSON string
func PostsToJSONString(posts []*Post) string {
	var sb strings.Builder
	sb.WriteString("[")

	for i, post := range posts {
		if i > 0 {
			sb.WriteString(",")
		}

		sb.WriteString(PostToJSONString(post))
	}
	sb.WriteString("]")

	return sb.String()
}

// PostToJSONString returns a Post formatted as a JSON string
// Note: Gno currently does not support reflection, which is why JSON marshalling is unavailable
func PostToJSONString(post *Post) string {
	var sb strings.Builder

	sb.WriteString("{")
	sb.WriteString(`"id":"` + post.ID + `",`)
	sb.WriteString(`"data":"` + escapeString(post.Data) + `",`)
	sb.WriteString(`"author":"` + escapeString(post.Author.String()) + `",`)
	sb.WriteString(`"timestamp":"` + strconv.Itoa(int(post.Timestamp.Unix())) + `",`)
	sb.WriteString(`"upvotes":` + strconv.Itoa(post.UpvoteTracker.Size()))
	sb.WriteString("}")

	return sb.String()
}

// escapeString escapes quotes in a string for JSON compatibility.
func escapeString(s string) string {
	return strings.ReplaceAll(s, `"`, `\"`)
}
