"use client";

import { useState, useEffect } from "react";
import { createClient } from "@/lib/supabase/client";
import { useUser } from "@/hooks/useUser";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { MessageSquare, Send, ThumbsUp, User } from "lucide-react";

interface Discussion {
  id: string;
  title: string;
  content: string;
  user_id: string;
  profiles?: { full_name: string | null; avatar_url: string | null };
  upvotes: number;
  created_at: string;
  replies?: Reply[];
}

interface Reply {
  id: string;
  content: string;
  user_id: string;
  profiles?: { full_name: string | null; avatar_url: string | null };
  upvotes: number;
  is_solution: boolean;
  created_at: string;
}

interface CourseDiscussionsProps {
  courseId: string;
}

export function CourseDiscussions({ courseId }: CourseDiscussionsProps) {
  const { user } = useUser();
  const supabase = createClient();
  const [discussions, setDiscussions] = useState<Discussion[]>([]);
  const [loading, setLoading] = useState(true);
  const [newDiscussion, setNewDiscussion] = useState({ title: "", content: "" });
  const [showNewForm, setShowNewForm] = useState(false);

  useEffect(() => {
    fetchDiscussions();
  }, [courseId]);

  const fetchDiscussions = async () => {
    try {
      const { data, error } = await supabase
        .from("course_discussions")
        .select("*, profiles(full_name, avatar_url)")
        .eq("course_id", courseId)
        .order("created_at", { ascending: false });

      if (error) throw error;

      // Fetch replies for each discussion
      const discussionsWithReplies = await Promise.all(
        (data || []).map(async (discussion) => {
          const { data: replies } = await supabase
            .from("discussion_replies")
            .select("*, profiles(full_name, avatar_url)")
            .eq("discussion_id", discussion.id)
            .order("created_at", { ascending: true });

          return { ...discussion, replies: replies || [] };
        })
      );

      setDiscussions(discussionsWithReplies);
    } catch (err) {
      console.error("Error fetching discussions:", err);
    } finally {
      setLoading(false);
    }
  };

  const createDiscussion = async () => {
    if (!user || !newDiscussion.title || !newDiscussion.content) return;

    try {
      const { error } = await supabase.from("course_discussions").insert({
        course_id: courseId,
        user_id: user.id,
        title: newDiscussion.title,
        content: newDiscussion.content,
      });

      if (error) throw error;

      setNewDiscussion({ title: "", content: "" });
      setShowNewForm(false);
      fetchDiscussions();
    } catch (err) {
      console.error("Error creating discussion:", err);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold text-foreground">Discussions</h3>
        {user && (
          <Button size="sm" onClick={() => setShowNewForm(!showNewForm)}>
            <MessageSquare className="w-4 h-4 mr-1" />
            New Question
          </Button>
        )}
      </div>

      {showNewForm && user && (
        <Card className="p-4">
          <Input
            placeholder="Question title"
            value={newDiscussion.title}
            onChange={(e) =>
              setNewDiscussion({ ...newDiscussion, title: e.target.value })
            }
            className="mb-2"
          />
          <textarea
            placeholder="Ask a question about this course..."
            value={newDiscussion.content}
            onChange={(e) =>
              setNewDiscussion({ ...newDiscussion, content: e.target.value })
            }
            className="w-full p-3 bg-background-secondary border border-background-tertiary rounded-lg text-foreground resize-none"
            rows={4}
          />
          <div className="flex gap-2 mt-2">
            <Button size="sm" onClick={createDiscussion}>
              <Send className="w-4 h-4 mr-1" />
              Post
            </Button>
            <Button
              size="sm"
              variant="outline"
              onClick={() => {
                setShowNewForm(false);
                setNewDiscussion({ title: "", content: "" });
              }}
            >
              Cancel
            </Button>
          </div>
        </Card>
      )}

      {discussions.length === 0 ? (
        <Card className="p-8 text-center">
          <MessageSquare className="w-12 h-12 text-foreground-muted mx-auto mb-2 opacity-50" />
          <p className="text-foreground-muted">No discussions yet</p>
          <p className="text-sm text-foreground-muted mt-1">
            Be the first to ask a question!
          </p>
        </Card>
      ) : (
        <div className="space-y-4">
          {discussions.map((discussion) => (
            <Card key={discussion.id} className="p-4">
              <div className="flex items-start gap-3">
                <div className="w-8 h-8 rounded-full bg-background-secondary flex items-center justify-center">
                  {discussion.profiles?.avatar_url ? (
                    <img
                      src={discussion.profiles.avatar_url}
                      alt={discussion.profiles.full_name || "User"}
                      className="w-full h-full rounded-full object-cover"
                    />
                  ) : (
                    <User className="w-4 h-4 text-foreground-muted" />
                  )}
                </div>
                <div className="flex-1">
                  <div className="flex items-start justify-between">
                    <div>
                      <h4 className="font-semibold text-foreground">
                        {discussion.title}
                      </h4>
                      <p className="text-sm text-foreground-muted mt-1">
                        {discussion.profiles?.full_name || "Anonymous"} •{" "}
                        {new Date(discussion.created_at).toLocaleDateString()}
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      <ThumbsUp className="w-4 h-4 text-foreground-muted" />
                      <span className="text-sm text-foreground-muted">
                        {discussion.upvotes}
                      </span>
                    </div>
                  </div>
                  <p className="text-foreground-muted mt-2">{discussion.content}</p>

                  {discussion.replies && discussion.replies.length > 0 && (
                    <div className="mt-4 space-y-2 pl-4 border-l-2 border-background-tertiary">
                      {discussion.replies.map((reply) => (
                        <div key={reply.id} className="flex items-start gap-2">
                          <div className="w-6 h-6 rounded-full bg-background-secondary flex items-center justify-center flex-shrink-0">
                            {reply.profiles?.avatar_url ? (
                              <img
                                src={reply.profiles.avatar_url}
                                alt={reply.profiles.full_name || "User"}
                                className="w-full h-full rounded-full object-cover"
                              />
                            ) : (
                              <User className="w-3 h-3 text-foreground-muted" />
                            )}
                          </div>
                          <div className="flex-1">
                            <p className="text-sm text-foreground">
                              {reply.profiles?.full_name || "Anonymous"}
                            </p>
                            <p className="text-sm text-foreground-muted">
                              {reply.content}
                            </p>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
