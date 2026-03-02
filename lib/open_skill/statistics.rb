# frozen_string_literal: true

# Port of https://github.com/philihp/openskill.js/blob/main/src/statistics.ts

module OpenSkill
  module Statistics
    # Standard normal PDF
    def self.phi_minor(x)
      Math.exp(-0.5 * x * x) / Math.sqrt(2 * Math::PI)
    end

    # Standard normal CDF via Math.erf
    def self.phi_major(x)
      0.5 * (1.0 + Math.erf(x / Math.sqrt(2)))
    end

    def self.v(x, t)
      xt = x - t
      denom = phi_major(xt)
      return -xt if denom < Float::EPSILON
      phi_minor(xt) / denom
    end

    def self.w(x, t)
      xt = x - t
      denom = phi_major(xt)
      if denom < Float::EPSILON
        return x < 0 ? 1 : 0
      end
      v(x, t) * (v(x, t) + xt)
    end

    def self.vt(x, t)
      xx = x.abs
      b = phi_major(t - xx) - phi_major(-t - xx)
      if b < 1e-5
        return x < 0 ? -x - t : -x + t
      end
      a = phi_minor(-t - xx) - phi_minor(t - xx)
      (x < 0 ? -a : a) / b
    end

    def self.wt(x, t)
      xx = x.abs
      b = phi_major(t - xx) - phi_major(-t - xx)
      return 1.0 if b < Float::EPSILON
      ((t - xx) * phi_minor(t - xx) + (t + xx) * phi_minor(-t - xx)) / b + vt(x, t)**2
    end
  end
end
