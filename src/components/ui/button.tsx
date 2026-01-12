"use client";

import { cn } from "@/lib/utils";
import { ButtonHTMLAttributes, forwardRef } from "react";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "secondary" | "ghost" | "danger";
  size?: "sm" | "md" | "lg";
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = "primary", size = "md", children, disabled, ...props }, ref) => {
    return (
      <button
        ref={ref}
        disabled={disabled}
        className={cn(
          "inline-flex items-center justify-center font-medium rounded-lg transition-all duration-200",
          "focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-background",
          "disabled:opacity-50 disabled:cursor-not-allowed",
          {
            // Variants
            "bg-accent-green text-white hover:bg-accent-green-light focus:ring-accent-green":
              variant === "primary",
            "bg-background-tertiary text-foreground hover:bg-card-hover focus:ring-background-tertiary":
              variant === "secondary",
            "bg-transparent text-foreground-muted hover:text-foreground hover:bg-background-secondary focus:ring-background-tertiary":
              variant === "ghost",
            "bg-accent-red text-white hover:bg-accent-red-light focus:ring-accent-red":
              variant === "danger",
            // Sizes
            "text-sm px-3 py-1.5": size === "sm",
            "text-sm px-4 py-2": size === "md",
            "text-base px-6 py-3": size === "lg",
          },
          className
        )}
        {...props}
      >
        {children}
      </button>
    );
  }
);

Button.displayName = "Button";

