// Real client quotes only. The Home page hides this section while the list is empty.
export interface Testimonial {
  quote: string;
  name: string;
  business: string;
}

export const testimonials: Testimonial[] = [];
