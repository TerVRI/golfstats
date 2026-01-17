import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { Progress } from './progress';

describe('Progress', () => {
  it('should render progress bar', () => {
    const { container } = render(<Progress value={50} />);
    const progressBar = container.querySelector('.bg-accent-green');
    expect(progressBar).toBeInTheDocument();
  });

  it('should set correct width for value', () => {
    const { container } = render(<Progress value={75} />);
    const progressBar = container.querySelector('.bg-accent-green') as HTMLElement;
    expect(progressBar?.style.width).toBe('75%');
  });

  it('should clamp value to 0-100', () => {
    const { container: container1 } = render(<Progress value={-10} />);
    const progressBar1 = container1.querySelector('.bg-accent-green') as HTMLElement;
    expect(progressBar1?.style.width).toBe('0%');

    const { container: container2 } = render(<Progress value={150} />);
    const progressBar2 = container2.querySelector('.bg-accent-green') as HTMLElement;
    expect(progressBar2?.style.width).toBe('100%');
  });

  it('should apply custom className', () => {
    const { container } = render(<Progress value={50} className="custom-class" />);
    expect(container.firstChild).toHaveClass('custom-class');
  });
});
