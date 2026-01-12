import Link from "next/link";
import { Button } from "@/components/ui";
import { Home, Flag } from "lucide-react";

export default function NotFound() {
  return (
    <div className="min-h-[400px] flex items-center justify-center">
      <div className="text-center max-w-md mx-auto px-4">
        <div className="w-20 h-20 rounded-full bg-background-secondary flex items-center justify-center mx-auto mb-6">
          <Flag className="w-10 h-10 text-foreground-muted" />
        </div>
        <h2 className="text-2xl font-bold text-foreground mb-2">Page Not Found</h2>
        <p className="text-foreground-muted mb-6">
          Looks like this hole doesn&apos;t exist. Let&apos;s get you back to the clubhouse.
        </p>
        <Link href="/dashboard">
          <Button>
            <Home className="w-4 h-4 mr-2" />
            Back to Dashboard
          </Button>
        </Link>
      </div>
    </div>
  );
}

